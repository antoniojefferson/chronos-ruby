module Chronos
  module Application
    # Coordinates bounded queueing, retry, backlog, circuit state, and delivery.
    #
    # @responsibility Move serialized events through explicit delivery states.
    # @motivation Keep resilience policy out of transports, workers, and the public facade.
    # @limits It stores only sanitized SerializedEvent objects and never writes to disk.
    # @collaborators RetryPolicy, CircuitBreaker, RemoteConfiguration, WorkerPool, and Transport.
    # @thread_safety Mutable state, backlog, queue, and circuit transitions are synchronized.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; independent of frameworks.
    # @example
    #   pipeline.enqueue(serialized_event)
    #   pipeline.flush(2.0)
    # @errors Transport and policy failures are contained and diagnosed.
    # @performance Queue, retry count, backlog, and state counters are strictly bounded.
    class DeliveryPipeline
      STATES = [:accepted, :queued, :serialized, :sent, :retried, :dropped, :rejected].freeze

      attr_reader :remote_configuration

      def initialize(config, transport, logger = nil, options = {})
        @config = config
        @transport = transport
        @logger = logger || Internal::SafeLogger.new(config.logger)
        initialize_resilience(options)
        initialize_storage(options)
      end

      def enqueue(event)
        record_pre_delivery(event)
        if @worker_pool.enqueue(event)
          transition(:queued)
          true
        else
          transition(:dropped)
          false
        end
      rescue StandardError => error
        diagnose(error)
        transition(:dropped)
        false
      end

      def deliver_sync(event)
        deliver_sync_result(event).success?
      end

      def deliver_sync_result(event)
        record_pre_delivery(event)
        deliver_with_backlog(event)
      rescue StandardError => error
        diagnose(error)
        store_in_backlog(event)
        Ports::TransportResult.new(:network_error, :error => error.class.name)
      end

      # WorkerPool delivery entry point. Events were counted when accepted into the queue.
      def send_event(event)
        deliver_with_backlog(event)
      rescue StandardError => error
        diagnose(error)
        store_in_backlog(event)
        Ports::TransportResult.new(:network_error, :error => error.class.name)
      end

      def capture_allowed?(event_type, fingerprint = nil)
        @remote_configuration.capture?(event_type, fingerprint)
      rescue StandardError => error
        diagnose(error)
        false
      end

      def event_enabled?(event_type)
        @remote_configuration.delivery_enabled?(event_type)
      rescue StandardError => error
        diagnose(error)
        false
      end

      def max_payload_size
        @remote_configuration.max_payload_size
      end

      def flush(timeout)
        @worker_pool.flush(timeout)
      end

      def close(timeout)
        return true if closed?

        @state_mutex.synchronize { @closed = true }
        flushed = @worker_pool.close(timeout)
        @transport.close
        flushed
      rescue StandardError => error
        diagnose(error)
        false
      end

      def diagnostics
        {
          :states => state_counts,
          :queue => @queue.stats,
          :backlog => @backlog.stats,
          :circuit => @circuit_breaker.state,
          :remote_configuration => @remote_configuration.to_h
        }
      end

      private

      def initialize_resilience(options)
        @clock = options[:clock] || method(:monotonic_time)
        @sleeper = options[:sleeper] || proc { |delay| sleep(delay) }
        @remote_configuration = options[:remote_configuration] || RemoteConfiguration.new(@config)
        @retry_policy = options[:retry_policy] || build_retry_policy(options[:random])
        @circuit_breaker = options[:circuit_breaker] || CircuitBreaker.new(
          @config.circuit_failure_threshold,
          @config.circuit_reset_timeout,
          @clock
        )
      end

      def initialize_storage(options)
        @backlog = options[:backlog] || Internal::MemoryBacklog.new(@config.backlog_size)
        @queue = options[:queue] || Internal::BoundedQueue.new(@config.queue_size)
        @state_mutex = Mutex.new
        @states = STATES.each_with_object({}) { |state, counts| counts[state] = 0 }
        @send_mutex = Mutex.new
        @last_send_at = nil
        @closed = false
        @worker_pool = options[:worker_pool] || Internal::WorkerPool.new(@queue, self, @config.workers, @logger)
      end

      def build_retry_policy(random)
        RetryPolicy.new(
          :max_retries => @config.max_retries,
          :base_interval => @config.retry_base_interval,
          :max_interval => @config.retry_max_interval,
          :jitter => @config.retry_jitter,
          :random => random
        )
      end

      def record_pre_delivery(event)
        raise ArgumentError, "delivery requires a SerializedEvent" unless event.is_a?(Core::SerializedEvent)
        raise Error, "delivery pipeline is closed" if closed?

        transition(:accepted)
        transition(:serialized)
      end

      def deliver_with_backlog(event)
        drain_one_backlog unless @backlog.empty?
        attempt_delivery(event)
      end

      def drain_one_backlog
        event = @backlog.shift
        attempt_delivery(event) if event
      end

      def attempt_delivery(event)
        unless @circuit_breaker.allow_request?
          transition(:retried)
          store_in_backlog(event)
          return Ports::TransportResult.new(:circuit_open)
        end

        retries = 0
        loop do
          wait_for_send_interval
          result = @transport.send_event(event)
          return finish_success(result) if result.success?
          return finish_permanent_failure(result) unless result.retryable?

          @circuit_breaker.record_failure
          unless @retry_policy.retry?(result, retries) && @circuit_breaker.allow_request?
            store_in_backlog(event)
            return result
          end

          retries += 1
          transition(:retried)
          @sleeper.call(@retry_policy.delay(retries, result))
        end
      end

      def finish_success(result)
        @circuit_breaker.record_success
        apply_remote_configuration(result)
        transition(:sent)
        result
      end

      def finish_permanent_failure(result)
        @circuit_breaker.record_success
        transition(result.status == :client_error ? :rejected : :dropped)
        result
      end

      def store_in_backlog(event)
        accepted = @backlog.push(event)
        transition(:dropped) unless accepted
        accepted
      rescue StandardError => error
        diagnose(error)
        transition(:dropped)
        false
      end

      def apply_remote_configuration(result)
        values = result.remote_configuration
        return unless values && @config.remote_configuration

        @remote_configuration.apply(values)
      end

      def wait_for_send_interval
        interval = @remote_configuration.send_interval
        return if interval <= 0.0

        @send_mutex.synchronize do
          now = @clock.call
          if @last_send_at
            remaining = interval - (now - @last_send_at)
            @sleeper.call(remaining) if remaining > 0.0
          end
          @last_send_at = @clock.call
        end
      end

      def transition(state)
        @state_mutex.synchronize { @states[state] += 1 }
      end

      def state_counts
        @state_mutex.synchronize { @states.dup }
      end

      def closed?
        @state_mutex.synchronize { @closed }
      end

      def diagnose(error)
        @logger.warn("Chronos delivery failed: #{error.class}")
      end

      def monotonic_time
        if Process.respond_to?(:clock_gettime) && defined?(Process::CLOCK_MONOTONIC)
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        else
          Time.now.to_f
        end
      end
    end
  end
end
