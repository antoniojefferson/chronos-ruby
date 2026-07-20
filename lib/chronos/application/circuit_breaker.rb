module Chronos
  module Application
    # Small circuit breaker for retryable transport failures.
    #
    # @responsibility Stop delivery attempts temporarily after repeated failures.
    # @motivation Prevent retry storms while the Chronos endpoint is unavailable.
    # @limits It keeps no payload and permits only one half-open probe.
    # @collaborators DeliveryPipeline and a monotonic clock.
    # @thread_safety All transitions are protected by a mutex.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   transport.send_event(event) if breaker.allow_request?
    # @errors Clock failures are contained by DeliveryPipeline.
    # @performance Constant time with fixed memory.
    class CircuitBreaker
      def initialize(failure_threshold, reset_timeout, clock)
        @failure_threshold = failure_threshold
        @reset_timeout = reset_timeout
        @clock = clock
        @state = :closed
        @failures = 0
        @opened_at = nil
        @probe_in_flight = false
        @mutex = Mutex.new
      end

      def allow_request?
        @mutex.synchronize do
          return true if @state == :closed
          return false if @state == :half_open && @probe_in_flight
          return false unless reset_elapsed?

          @state = :half_open
          @probe_in_flight = true
          true
        end
      end

      def record_success
        @mutex.synchronize do
          @state = :closed
          @failures = 0
          @opened_at = nil
          @probe_in_flight = false
        end
      end

      def record_failure
        @mutex.synchronize do
          @failures += 1
          if @state == :half_open || @failures >= @failure_threshold
            @state = :open
            @opened_at = @clock.call
          end
          @probe_in_flight = false
        end
      end

      def state
        @mutex.synchronize { @state }
      end

      private

      def reset_elapsed?
        @opened_at && (@clock.call - @opened_at >= @reset_timeout)
      end
    end
  end
end
