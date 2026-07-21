module Chronos
  module Integrations
    # Builds bounded job metadata before the shared privacy serializer runs.
    #
    # @responsibility Limit job arguments, tags, strings, containers, and nesting.
    # @motivation Worker payloads are application-controlled and may be very large.
    # @limits It limits values but deliberately leaves redaction to Core::Sanitizer.
    # @collaborators Sidekiq middleware and the Chronos telemetry pipeline.
    # @thread_safety Instances keep no mutable state and may be shared.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   JobPayload.new.arguments(["account-1"])
    # @errors Unreadable values become bounded class-name placeholders.
    # @performance Traversal is capped by argument, collection, depth, and string limits.
    class JobPayload
      MAX_ARGUMENTS = 20
      MAX_COLLECTION_ITEMS = 20
      MAX_DEPTH = 4
      MAX_STRING_BYTES = 512

      def arguments(values)
        source = values.is_a?(Array) ? values : []
        [source.first(MAX_ARGUMENTS).map { |value| limit(value, 0) }, source.length > MAX_ARGUMENTS]
      rescue StandardError
        [[], true]
      end

      def tags(values)
        Array(values).first(MAX_COLLECTION_ITEMS).map { |value| limit_string(value.to_s) }
      rescue StandardError
        []
      end

      private

      def limit(value, depth)
        return "[TRUNCATED]" if depth >= MAX_DEPTH

        case value
        when Hash
          limit_hash(value, depth)
        when Array
          value.first(MAX_COLLECTION_ITEMS).map { |child| limit(child, depth + 1) }
        when String
          limit_string(value)
        when NilClass, TrueClass, FalseClass, Numeric
          value
        else
          limit_string(value.to_s)
        end
      rescue StandardError
        "[UNREADABLE]"
      end

      def limit_hash(value, depth)
        result = {}
        value.to_a.first(MAX_COLLECTION_ITEMS).each do |key, child|
          result[limit_string(key.to_s)] = limit(child, depth + 1)
        end
        result
      end

      def limit_string(value)
        return value if value.bytesize <= MAX_STRING_BYTES

        value.byteslice(0, MAX_STRING_BYTES) + "[TRUNCATED]"
      rescue StandardError
        "[UNREADABLE]"
      end
    end
  end
end
