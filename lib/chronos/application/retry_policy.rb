require "time"

module Chronos
  module Application
    # Bounded retry timing policy with exponential backoff and jitter.
    #
    # @responsibility Decide whether and when a retry may occur.
    # @motivation Centralize retry limits independently from HTTP and worker code.
    # @limits It does not sleep, send events, or retain payloads.
    # @collaborators TransportResult and DeliveryPipeline.
    # @thread_safety Immutable after construction when the random callable is thread-safe.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   policy.delay(2, result)
    # @errors Invalid configuration is rejected by Configuration.
    # @performance Constant time per decision.
    class RetryPolicy
      def initialize(options)
        @max_retries = options[:max_retries]
        @base_interval = options[:base_interval]
        @max_interval = options[:max_interval]
        @jitter = options[:jitter]
        @random = options[:random] || proc { rand }
      end

      def retry?(result, retries)
        result.retryable? && retries < @max_retries
      end

      def delay(retry_number, result = nil)
        retry_after = retry_after_seconds(result)
        return [retry_after, @max_interval].min if retry_after

        base = @base_interval * (2**(retry_number - 1))
        jittered = base * (1.0 + (@random.call.to_f * @jitter))
        [jittered, @max_interval].min
      end

      private

      def retry_after_seconds(result)
        return nil unless result && result.retry_after

        value = result.retry_after.to_s
        seconds = Float(value)
        seconds >= 0 ? seconds : nil
      rescue ArgumentError, TypeError
        begin
          seconds = Time.httpdate(value) - Time.now
          seconds > 0 ? seconds : nil
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
