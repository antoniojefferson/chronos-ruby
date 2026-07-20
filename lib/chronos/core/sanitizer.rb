require "digest"

module Chronos
  module Core
    # Removes secrets and personal data from event values before serialization.
    #
    # @responsibility Recursively redact configured keys and recognized sensitive strings.
    # @motivation Make privacy protection the default before transport or future persistence.
    # @limits Detection is conservative and cannot replace an application data-governance review.
    # @collaborators Configuration::Snapshot and application-provided filters.
    # @thread_safety Instances are immutable; configured filters must be thread-safe.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; independent of frameworks.
    # @example
    #   sanitizer.call("password" => "secret") #=> {"password"=>"[FILTERED]"}
    # @errors Unsafe values and failing custom filters become redacted placeholders.
    # @performance Work is linear in the structurally bounded event tree.
    class Sanitizer
      FILTERED = SensitiveValueFilter::FILTERED
      MAX_DEPTH = 10
      MAX_KEYS = 100
      MAX_ITEMS = 100
      MAX_NODES = 2_000

      def initialize(config)
        @blocklist_names, @blocklist_patterns = compile_matchers(config.blocklist_keys)
        @allowlist_names, @allowlist_patterns = compile_matchers(config.allowlist_keys)
        @hash_names, @hash_patterns = compile_matchers(config.hash_keys)
        @filters = config.filters
        @sensitive_value_filter = SensitiveValueFilter.new(config.anonymize_ip)
        @hash_scope = config.project_id.to_s
        freeze
      end

      def call(value)
        sanitize_value(value, nil, true, 0, :nodes => 0, :seen => {})
      rescue StandardError
        FILTERED
      end

      private

      def sanitize_value(value, key, run_filters, depth, state)
        state[:nodes] += 1
        return "<node limit reached>" if state[:nodes] > MAX_NODES
        return "<maximum depth reached>" if depth >= MAX_DEPTH

        result = sanitize_type(value, depth, state)
        run_filters && key && !@filters.empty? ? filter_value(key, result, depth, state) : result
      rescue StandardError
        FILTERED
      end

      def sanitize_type(value, depth, state)
        return sanitize_hash(value, depth, state) if value.is_a?(Hash)
        return sanitize_array(value, depth, state) if value.is_a?(Array)
        return @sensitive_value_filter.call(value) if value.is_a?(String)

        value
      end

      def sanitize_hash(value, depth, state)
        return "<circular reference>" if state[:seen][value.object_id]

        state[:seen][value.object_id] = true
        result = {}
        value.to_a.first(MAX_KEYS).each do |key, child|
          result[key] = sanitize_hash_value(key, child, depth, state)
        end
        state[:seen].delete(value.object_id)
        result
      end

      def sanitize_hash_value(key, value, depth, state)
        return FILTERED if blocked_key?(key) && !allowed_key?(key)
        return hash_value(value) if hashed_key?(key)

        sanitize_value(value, key, true, depth + 1, state)
      end

      def sanitize_array(value, depth, state)
        return "<circular reference>" if state[:seen][value.object_id]

        state[:seen][value.object_id] = true
        result = value.first(MAX_ITEMS).map do |child|
          sanitize_value(child, nil, true, depth + 1, state)
        end
        state[:seen].delete(value.object_id)
        result
      end

      def blocked_key?(key)
        matches_any?(@blocklist_names, @blocklist_patterns, key, true)
      end

      def allowed_key?(key)
        matches_any?(@allowlist_names, @allowlist_patterns, key, false)
      end

      def hashed_key?(key)
        matches_any?(@hash_names, @hash_patterns, key, false)
      end

      def compile_matchers(matchers)
        names = []
        patterns = []
        matchers.each do |matcher|
          matcher.is_a?(Regexp) ? patterns << matcher : names << normalize_key(matcher)
        end
        [names.freeze, patterns.freeze]
      end

      def matches_any?(names, patterns, key, fallback)
        candidate = safe_key(key)
        key_name = normalize_key(candidate)
        name_match = names.any? { |name| key_name == name || key_name.end_with?("_#{name}") }
        name_match || patterns.any? { |pattern| pattern =~ candidate }
      rescue StandardError
        fallback
      end

      def normalize_key(value)
        value.to_s.downcase.gsub(/[^a-z0-9]+/, "_").sub(/\A_+/, "").sub(/_+\z/, "")
      end

      def safe_key(value)
        return value if value.is_a?(String)
        return value.to_s if value.is_a?(Symbol) || value.is_a?(Numeric)

        "<#{safe_class_name(value)}>"
      rescue StandardError
        "<unreadable key>"
      end

      def hash_value(value)
        scalar = case value
                 when String, Symbol, Numeric
                   value.to_s
                 else
                   return FILTERED
                 end
        digest = Digest::SHA256.hexdigest("chronos:#{@hash_scope}:#{scalar}")
        "[HASHED_SHA256:#{digest}]"
      rescue StandardError
        FILTERED
      end

      def filter_value(key, value, depth, state)
        filtered = @filters.inject(value) { |current, filter| filter.call(key, current) }
        sanitize_value(filtered, nil, false, depth, state)
      rescue StandardError
        FILTERED
      end

      def safe_class_name(value)
        value.class.name.to_s
      rescue StandardError
        "Object"
      end
    end
  end
end
