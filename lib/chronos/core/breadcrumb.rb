require "json"
require "time"

module Chronos
  module Core
    # Immutable, bounded diagnostic marker attached to an execution.
    #
    # @responsibility Normalize one breadcrumb without retaining raw application objects.
    # @motivation Preserve useful events leading to an exception with predictable memory use.
    # @limits It does not capture logs, SQL, bodies, or HTTP calls automatically.
    # @collaborators SafeSerializer and BreadcrumbBuffer.
    # @thread_safety Immutable after construction.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   breadcrumb.to_h #=> {"category"=>"custom", ...}
    # @errors Unserializable metadata is replaced by SafeSerializer placeholders.
    # @performance Metadata traversal has strict depth, node, item, and byte limits.
    class Breadcrumb
      CATEGORIES = %w(custom log request query external_http cache job).freeze

      def initialize(attributes, clock = nil, max_bytes = 2048)
        attributes = {} unless attributes.is_a?(Hash)
        clock ||= proc { Time.now }
        serializer = SafeSerializer.new(
          :max_depth => 5, :max_keys => 20, :max_items => 20,
          :max_string_bytes => 512, :max_nodes => 100
        )
        @data = serializer.call(build_data(attributes, clock))
        @data = compact_data(@data, max_bytes) if JSON.generate(@data).bytesize > max_bytes
        deep_freeze(@data)
        freeze
      end

      def to_h
        @data
      end

      private

      def build_data(attributes, clock)
        category = value(attributes, :category).to_s
        category = "custom" unless CATEGORIES.include?(category)
        {
          "category" => category,
          "message" => value(attributes, :message).to_s,
          "metadata" => value(attributes, :metadata) || {},
          "timestamp" => clock.call.utc.iso8601(6)
        }
      end

      def compact_data(data, max_bytes)
        message_limit = [max_bytes / 4, 32].max
        compacted = {
          "category" => data["category"],
          "message" => SafeSerializer.new.call(data["message"], :max_string_bytes => message_limit),
          "metadata" => {"_truncated" => true},
          "timestamp" => data["timestamp"]
        }
        trim_compacted_message(compacted, max_bytes)
      end

      def trim_compacted_message(compacted, max_bytes)
        while JSON.generate(compacted).bytesize > max_bytes && !compacted["message"].empty?
          length = [compacted["message"].bytesize - 16, 0].max
          compacted["message"] = SafeSerializer.new.call(
            compacted["message"].byteslice(0, length).to_s,
            :max_string_bytes => length
          )
        end
        compacted
      end

      def value(attributes, key)
        attributes.key?(key) ? attributes[key] : attributes[key.to_s]
      end

      def deep_freeze(value)
        if value.is_a?(Hash)
          value.each do |key, child|
            deep_freeze(key)
            deep_freeze(child)
          end
        elsif value.is_a?(Array)
          value.each { |child| deep_freeze(child) }
        end
        value.freeze
      end
    end

    # Fixed-size circular collection of execution breadcrumbs.
    #
    # @responsibility Retain only the newest bounded breadcrumbs for one execution.
    # @motivation Prevent long requests or noisy instrumentation from growing memory indefinitely.
    # @limits It is process memory only and does not collect events by itself.
    # @collaborators Breadcrumb and Agent.
    # @thread_safety Intended for one execution thread; snapshots are immutable values.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   buffer.add(:category => "custom", :message => "started")
    # @errors Invalid attributes are normalized into a safe breadcrumb.
    # @performance Add is constant time and storage never exceeds capacity.
    class BreadcrumbBuffer
      def initialize(capacity, max_bytes = 2048)
        raise ArgumentError, "capacity must be a positive integer" unless capacity.is_a?(Integer) && capacity > 0

        @capacity = capacity
        @max_bytes = max_bytes
        @items = []
      end

      def add(attributes)
        @items.shift if @items.length >= @capacity
        @items << Breadcrumb.new(attributes, nil, @max_bytes)
        true
      end

      def to_a
        @items.map(&:to_h)
      end

      def size
        @items.size
      end
    end
  end
end
