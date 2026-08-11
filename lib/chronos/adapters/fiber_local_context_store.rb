module Chronos
  module Adapters
    # Stores execution context on the current Fiber when Ruby exposes Fiber storage.
    #
    # @responsibility Isolate context between concurrent fibers and restore nested scopes.
    # @motivation Rails 7 applications increasingly multiplex work on one thread.
    # @limits Fiber storage is not propagated automatically to newly-created fibers.
    # @collaborators ContextStore port and Agent composition root.
    # @thread_safety Each fiber owns its value and may be used from concurrent threads.
    # @compatibility Ruby 3.2+ Fiber storage; falls back to thread-local storage otherwise.
    # @example
    #   store.with_context(:request_id => "r1") { store.get }
    # @errors Previous context is restored even when the block raises.
    # @performance Constant-time storage operations with a bounded hash merge.
    class FiberLocalContextStore
      def initialize(fallback = ThreadLocalContextStore.new)
        @key = "chronos_context_#{object_id}".to_sym
        @fallback = fallback
      end

      def get
        supported? ? (Fiber[@key] || {}) : @fallback.get
      end

      def set(context)
        raise ArgumentError, "context must be a Hash" unless context.is_a?(Hash)

        supported? ? Fiber[@key] = context : @fallback.set(context)
      end

      def clear
        supported? ? Fiber[@key] = nil : @fallback.clear
        nil
      end

      def with_context(context)
        previous = get
        set(previous.merge(valid_context(context)))
        yield
      ensure
        previous && !previous.empty? ? set(previous) : clear
      end

      private

      def supported?
        Fiber.respond_to?(:[]) && Fiber.respond_to?(:[]=)
      end

      def valid_context(context)
        raise ArgumentError, "context must be a Hash" unless context.is_a?(Hash)

        context
      end
    end
  end
end
