module Chronos
  module Internal
    # Thread-safe queue with fixed capacity and non-blocking producer behavior.
    #
    # @responsibility Accept events up to a limit and count accepted and dropped items.
    # @motivation Prevent telemetry bursts from growing application memory indefinitely.
    # @limits Version 0.3 drops the newest item when full and does not persist to disk.
    # @collaborators WorkerPool.
    # @thread_safety Mutex and condition variable protect all mutable state.
    # @compatibility Ruby 2.2.10 through Ruby 2.6 and fork-aware callers.
    # @example
    #   queue.push(event) #=> true or false
    # @performance Push is constant-time and never waits for free capacity.
    class BoundedQueue
      attr_reader :capacity

      def initialize(capacity)
        raise ArgumentError, "capacity must be positive" unless capacity.is_a?(Integer) && capacity > 0

        @capacity = capacity
        @items = []
        @accepted = 0
        @dropped = 0
        @closed = false
        @mutex = Mutex.new
        @condition = ConditionVariable.new
      end

      def push(item)
        @mutex.synchronize do
          return false if @closed
          if @items.length >= @capacity
            @dropped += 1
            return false
          end

          @items << item
          @accepted += 1
          @condition.signal
          true
        end
      end

      def pop(timeout = nil)
        @mutex.synchronize do
          @condition.wait(@mutex, timeout) while @items.empty? && !@closed && timeout.nil?
          @condition.wait(@mutex, timeout) if @items.empty? && !@closed && timeout
          @items.shift
        end
      end

      def close
        @mutex.synchronize do
          @closed = true
          @condition.broadcast
        end
        true
      end

      def closed?
        @mutex.synchronize { @closed }
      end

      def empty?
        @mutex.synchronize { @items.empty? }
      end

      def size
        @mutex.synchronize { @items.size }
      end

      def stats
        @mutex.synchronize do
          {:size => @items.size, :capacity => capacity, :accepted => @accepted, :dropped => @dropped}
        end
      end
    end
  end
end
