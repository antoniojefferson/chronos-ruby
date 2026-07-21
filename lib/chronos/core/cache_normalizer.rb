require "digest"

module Chronos
  module Core
    # Produces bounded cache metadata without exposing raw cache keys or values.
    #
    # @responsibility Normalize operation, backend, namespace, outcome, and optional key hash.
    # @motivation Cache telemetry needs diagnostic identity without leaking application keys.
    # @limits It never reads cache values and hashes keys only after explicit opt-in.
    # @collaborators Rails notification subscriber and Chronos configuration.
    # @thread_safety Instances hold only immutable scalar configuration.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   CacheNormalizer.new("project", :none).call(name, payload)
    # @errors Unreadable fields become empty bounded strings.
    # @performance Constant work plus SHA-256 only when key hashing is enabled.
    class CacheNormalizer
      def initialize(project_id, key_mode)
        @project_id = project_id.to_s
        @key_mode = key_mode
      end

      def call(name, payload = {})
        hit = hit_value(name, payload)
        result = {
          "operation" => bounded(name.to_s.split(".").first, 64),
          "backend" => backend(payload),
          "namespace" => bounded(namespace(payload).to_s, 128),
          "hit" => hit,
          "outcome" => outcome(hit)
        }
        result["key_hash"] = key_hash(value(payload, :key)) if @key_mode == :sha256
        result.delete_if { |key, child| child.to_s.empty? && key != "hit" }
      rescue StandardError
        {"operation" => "cache", "outcome" => "unknown"}
      end

      private

      def outcome(hit)
        return "unknown" if hit.nil?

        hit ? "hit" : "miss"
      end

      def backend(payload)
        store = value(payload, :store)
        return "" if store.nil?

        name = store.is_a?(String) || store.is_a?(Symbol) ? store.to_s : store.class.name.to_s
        bounded(name, 128)
      rescue StandardError
        ""
      end

      def namespace(payload)
        direct = value(payload, :namespace)
        return direct unless direct.nil?

        value(value(payload, :options), :namespace)
      end

      def hit_value(name, payload)
        return true if name.to_s.start_with?("cache_fetch_hit")

        hit = value(payload, :hit)
        [true, false].include?(hit) ? hit : nil
      end

      def key_hash(key)
        return nil if key.nil?

        Digest::SHA256.hexdigest("#{@project_id}:cache:#{safe_key(key)}")
      end

      def safe_key(key)
        text = key.to_s
        text = text.scrub("?") if text.respond_to?(:scrub)
        text.bytesize > 2048 ? text.byteslice(0, 2048) : text
      rescue StandardError
        "[UNREADABLE]"
      end

      def value(hash, key)
        return nil unless hash.is_a?(Hash)

        hash.key?(key) ? hash[key] : hash[key.to_s]
      end

      def bounded(value, limit)
        text = value.to_s
        text = text.scrub("?") if text.respond_to?(:scrub)
        text.bytesize > limit ? text.byteslice(0, limit) : text
      rescue StandardError
        ""
      end
    end
  end
end
