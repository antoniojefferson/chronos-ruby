require "digest"

module Chronos
  module Core
    # Produces bounded, value-free SQL metadata for aggregation and local signals.
    #
    # @responsibility Remove comments/literals and derive operation, table, and fingerprint.
    # @motivation SQL metrics need stable low-cardinality identity without bind values.
    # @limits It is a defensive lexer, not a complete dialect-specific SQL parser.
    # @collaborators Rails notification adapter and APM aggregator.
    # @thread_safety Instances are stateless and safe to share.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; no ActiveRecord dependency.
    # @example
    #   SqlNormalizer.new.call("SELECT * FROM users WHERE id = 42")
    # @errors Malformed or unreadable input returns bounded unknown metadata.
    # @performance Input and normalized output are capped before fingerprinting.
    class SqlNormalizer
      MAX_SQL_BYTES = 4096
      MAX_NORMALIZED_BYTES = 512
      KEYWORDS = %w(
        select insert update delete from into where join left right inner outer on set values
        and or order group by having limit offset as distinct begin commit rollback savepoint release
      ).freeze

      def call(sql, metadata = {})
        normalized = normalize(sql)
        {
          "adapter" => adapter(metadata), "operation" => operation(normalized),
          "table" => table(normalized), "normalized_query" => normalized,
          "fingerprint" => Digest::SHA256.hexdigest(normalized),
          "name" => value(metadata, :name).to_s,
          "cached" => value(metadata, :cached) == true,
          "role" => optional_string(metadata, :role, :connection_role),
          "shard" => optional_string(metadata, :shard, :connection_shard),
          "source" => bounded(value(metadata, :source).to_s, 256),
          "error_class" => error_class(metadata)
        }.delete_if { |_key, child| child.nil? || child == "" }
      rescue StandardError
        {"operation" => "UNKNOWN", "normalized_query" => "", "fingerprint" => Digest::SHA256.hexdigest("")}
      end

      private

      def normalize(sql)
        text = bounded(sql.to_s, MAX_SQL_BYTES)
        text = text.gsub(%r{/\*.*?\*/}m, " ").gsub(/--[^\r\n]*/, " ")
        text = text.gsub(/'(?:''|[^'])*'/, "?")
        text = text.gsub(/\$([A-Za-z_][A-Za-z0-9_]*)?\$.*?\$\1\$/m, "?")
        text = text.gsub(/\b(?:0x[0-9a-f]+|\d+(?:\.\d+)?)\b/i, "?")
        text = text.gsub(/\b(?:true|false|null)\b/i, "?")
        text = text.gsub(/\(\s*\?(?:\s*,\s*\?)+\s*\)/, "(?)")
        text = text.gsub(/\s+/, " ").strip
        KEYWORDS.each { |keyword| text.gsub!(/\b#{keyword}\b/i, keyword.upcase) }
        bounded(text, MAX_NORMALIZED_BYTES)
      end

      def operation(normalized)
        candidate = normalized.to_s.split(/\s+/, 2).first.to_s.upcase
        candidate =~ /\A[A-Z]+\z/ ? candidate : "UNKNOWN"
      end

      def table(normalized)
        match = normalized.match(/\b(?:FROM|INTO|UPDATE|JOIN)\s+["`\[]?([A-Za-z0-9_.-]+)/i)
        bounded(match && match[1].to_s, 128)
      end

      def adapter(metadata)
        direct = value(metadata, :adapter)
        return bounded(direct.to_s, 64) unless direct.to_s.empty?

        connection = value(metadata, :connection)
        return "" unless connection && connection.respond_to?(:adapter_name)

        bounded(connection.adapter_name.to_s, 64)
      rescue StandardError
        ""
      end

      def error_class(metadata)
        error = value(metadata, :exception_object) || value(metadata, :exception)
        return error.class.name.to_s if error.is_a?(Exception)
        return Array(error).first.to_s unless error.nil?

        ""
      rescue StandardError
        ""
      end

      def optional_string(metadata, *names)
        names.each do |name|
          candidate = value(metadata, name)
          return bounded(candidate.to_s, 64) unless candidate.to_s.empty?
        end
        ""
      end

      def value(hash, key)
        return nil unless hash.is_a?(Hash)

        hash.key?(key) ? hash[key] : hash[key.to_s]
      end

      def bounded(value, limit)
        text = value.to_s
        text = text.scrub("?") if text.respond_to?(:scrub)
        return text if text.bytesize <= limit

        text.byteslice(0, limit)
      rescue StandardError
        ""
      end
    end
  end
end
