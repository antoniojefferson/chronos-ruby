module Chronos
  module Core
    # Converts bounded Ruby structures to values accepted by JSON.generate.
    #
    # @responsibility Normalize only JSON primitives while enforcing structural budgets.
    # @motivation Prevent application objects, cycles, or invalid encoding from breaking capture.
    # @limits It does not redact secrets; Sanitizer must run before this component.
    # @collaborators PayloadSerializer.
    # @thread_safety Each call owns its traversal state and can run concurrently.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   serializer.call(:status => :ok) #=> {"status"=>"ok"}
    # @errors Individual unreadable values become bounded placeholders.
    # @performance Depth, nodes, keys, items, and string bytes are bounded.
    class SafeSerializer
      DEFAULTS = {
        :max_depth => 10,
        :max_keys => 100,
        :max_items => 100,
        :max_string_bytes => 8192,
        :max_nodes => 2_000
      }.freeze

      def initialize(options = {})
        @options = DEFAULTS.merge(options).freeze
      end

      def call(value, overrides = {})
        settings = @options.merge(overrides)
        normalize(value, 0, {}, {:nodes => 0}, settings)
      rescue StandardError
        "<unserializable value>"
      end

      private

      def normalize(value, depth, seen, state, settings)
        state[:nodes] += 1
        return "<node limit reached>" if state[:nodes] > settings[:max_nodes]
        return "<maximum depth reached>" if depth >= settings[:max_depth]

        return normalize_array(value, depth, seen, state, settings) if value.is_a?(Array)
        return normalize_hash(value, depth, seen, state, settings) if value.is_a?(Hash)

        normalize_scalar(value, settings)
      rescue StandardError
        "<unserializable value>"
      end

      def normalize_scalar(value, settings)
        case value
        when nil, true, false, Integer
          value
        when Float
          value.finite? ? value : value.to_s
        when String
          truncate_string(safe_string(value), settings[:max_string_bytes])
        when Symbol
          truncate_string(value.to_s, settings[:max_string_bytes])
        else
          "<#{safe_class_name(value)}>"
        end
      end

      def normalize_array(value, depth, seen, state, settings)
        return "<circular reference>" if seen[value.object_id]

        seen[value.object_id] = true
        result = value.first(settings[:max_items]).map do |child|
          normalize(child, depth + 1, seen, state, settings)
        end
        seen.delete(value.object_id)
        result
      end

      def normalize_hash(value, depth, seen, state, settings)
        return "<circular reference>" if seen[value.object_id]

        seen[value.object_id] = true
        result = {}
        value.to_a.first(settings[:max_keys]).each do |key, child|
          result[safe_key(key)] = normalize(child, depth + 1, seen, state, settings)
        end
        seen.delete(value.object_id)
        result
      end

      def safe_key(value)
        string = if value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(Numeric)
                   value.to_s
                 else
                   "<#{safe_class_name(value)}>"
                 end
        truncate_string(safe_string(string), 256)
      rescue StandardError
        "<unreadable key>"
      end

      def safe_string(value)
        value.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "�")
      rescue StandardError
        "<unreadable value>"
      end

      def truncate_string(value, limit)
        return value if value.bytesize <= limit

        prefix = value.byteslice(0, limit).to_s
        safe_string(prefix) + "…"
      end

      def safe_class_name(value)
        value.class.name.to_s
      rescue StandardError
        "Object"
      end
    end
  end
end
