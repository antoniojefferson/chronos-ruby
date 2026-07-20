module Chronos
  module Internal
    # Fixed-capacity retry storage for sanitized serialized events.
    #
    # @responsibility Retain failed deliveries in memory without unbounded growth.
    # @motivation Allow later recovery while preserving the host application's memory limit.
    # @limits It never writes to disk and accepts only SerializedEvent instances.
    # @collaborators DeliveryPipeline and SerializedEvent.
    # @thread_safety A mutex protects storage and counters.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   backlog.push(serialized_event)
    # @errors Invalid event types raise before entering storage.
    # @performance Push and shift are bounded by the configured capacity.
    class MemoryBacklog
      attr_reader :capacity

      def initialize(capacity)
        unless capacity.is_a?(Integer) && capacity >= 0
          raise ArgumentError, "capacity must be a non-negative integer"
        end

        @capacity = capacity
        @items = []
        @accepted = 0
        @dropped = 0
        @mutex = Mutex.new
      end

      def push(event)
        unless event.is_a?(Core::SerializedEvent)
          raise ArgumentError, "backlog accepts only sanitized serialized events"
        end

        @mutex.synchronize do
          if @items.length >= capacity
            @dropped += 1
            return false
          end
          @items << event
          @accepted += 1
          true
        end
      end

      def shift
        @mutex.synchronize { @items.shift }
      end

      def size
        @mutex.synchronize { @items.size }
      end

      def empty?
        size.zero?
      end

      def stats
        @mutex.synchronize do
          {:size => @items.size, :capacity => capacity, :accepted => @accepted, :dropped => @dropped}
        end
      end
    end
  end
end
