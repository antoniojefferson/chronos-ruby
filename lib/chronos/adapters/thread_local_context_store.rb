module Chronos
  module Adapters
    # Stores execution context in the current Ruby thread.
    #
    # @responsibility Isolate request context and restore nested scopes reliably.
    # @motivation Legacy Ruby does not provide a portable fiber-local storage API.
    # @limits Context does not propagate to new threads or across processes.
    # @collaborators ContextStore port and Rack middleware.
    # @thread_safety Each thread owns an independent value; one instance may be shared.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   store.with_context(:request_id => "r1") { store.get }
    # @errors The previous value is restored in ensure even when the block raises.
    # @performance Reads and writes are constant-time thread-local operations.
    class ThreadLocalContextStore
      def initialize
        @key = "chronos_context_#{object_id}".freeze
      end

      def get
        Thread.current[@key] || {}
      end

      def set(context)
        raise ArgumentError, "context must be a Hash" unless context.is_a?(Hash)

        Thread.current[@key] = context
      end

      def clear
        Thread.current[@key] = nil
        nil
      end

      def with_context(context)
        previous = Thread.current[@key]
        set(merge_context(previous || {}, context))
        yield
      ensure
        previous ? Thread.current[@key] = previous : clear
      end

      private

      def merge_context(current, additional)
        raise ArgumentError, "context must be a Hash" unless additional.is_a?(Hash)

        current.merge(additional)
      end
    end
  end
end
