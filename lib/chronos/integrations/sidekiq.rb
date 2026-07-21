require "securerandom"
require "chronos/integrations/job_payload"

module Chronos
  module Integrations
    # Optional Sidekiq 4/5 middleware integration for the legacy Chronos line.
    #
    # @responsibility Install client/server middleware and namespace worker telemetry.
    # @motivation Sidekiq jobs need process-boundary context and failure capture.
    # @limits It does not own Sidekiq lifecycle, Redis connections, retries, or threads.
    # @collaborators Sidekiq public middleware configuration and Chronos facade.
    # @thread_safety Installation is mutex-protected; middleware instances are stateless.
    # @compatibility Sidekiq 4.x and 5.x; Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   Chronos::Integrations::Sidekiq.install
    # @errors Missing Sidekiq or configuration failures return false.
    # @performance Adds bounded payload normalization and two clock reads per performed job.
    module Sidekiq
      CONTEXT_KEY = "chronos".freeze
      CONTEXT_SCHEMA_VERSION = "1.0".freeze

      @mutex = Mutex.new
      @installed = false

      class << self
        def install(sidekiq = nil, notifier = Chronos)
          library = sidekiq || (::Sidekiq if defined?(::Sidekiq))
          return false unless library

          @mutex.synchronize do
            return false if @installed

            configure_client(library, notifier)
            configure_server(library, notifier)
            @installed = true
          end
          true
        rescue StandardError
          false
        end

        private

        def configure_client(library, notifier)
          return unless library.respond_to?(:configure_client)

          library.configure_client do |config|
            next unless config.respond_to?(:client_middleware)

            config.client_middleware { |chain| chain.add(ClientMiddleware, :notifier => notifier) }
          end
        end

        def configure_server(library, notifier)
          return unless library.respond_to?(:configure_server)

          library.configure_server do |config|
            if config.respond_to?(:client_middleware)
              config.client_middleware { |chain| chain.add(ClientMiddleware, :notifier => notifier) }
            end
            if config.respond_to?(:server_middleware)
              config.server_middleware { |chain| chain.add(ServerMiddleware, :notifier => notifier) }
            end
          end
        end
      end

      # Adds a small allowlisted Chronos context to the Sidekiq job envelope.
      #
      # @responsibility Propagate trace/request identifiers without modifying `args`.
      # @motivation Client and server usually execute in different processes.
      # @limits It does not capture arguments, enqueue errors, or application context fields.
      # @collaborators Chronos propagation context and Sidekiq client middleware chain.
      # @thread_safety Calls allocate their own hashes and may execute concurrently.
      # @compatibility Sidekiq 4.x/5.x client middleware signature.
      # @example
      #   ClientMiddleware.new.call(MyWorker, job, "default") { push(job) }
      # @errors Context failures are contained and the enqueue chain still runs.
      # @performance Adds one bounded hash to the job payload; opens no connection or thread.
      class ClientMiddleware
        def initialize(options = {})
          @notifier = options[:notifier] || Chronos
          @clock = options[:clock] || proc { Time.now.to_f }
        end

        def call(_worker_class, job, _queue, _redis_pool = nil)
          add_context(job)
          yield
        end

        private

        def add_context(job)
          return unless job.is_a?(Hash)

          context = propagation_context
          context["trace_id"] = SecureRandom.uuid if context["trace_id"].to_s.empty?
          job[CONTEXT_KEY] = {
            "schema_version" => CONTEXT_SCHEMA_VERSION,
            "enqueued_at" => @clock.call.to_f,
            "context" => context
          }
        rescue StandardError
          nil
        end

        def propagation_context
          return {} unless @notifier.respond_to?(:propagation_context)

          source = @notifier.propagation_context
          return {} unless source.is_a?(Hash)

          %w(trace_id request_id).each_with_object({}) do |key, result|
            value = source[key] || source[key.to_sym]
            result[key] = value.to_s unless value.to_s.empty?
          end
        end
      end

      # Captures Sidekiq execution timing and failures around the worker call.
      #
      # @responsibility Scope propagated context, emit one job event, notify failures once, and re-raise.
      # @motivation Worker failures otherwise lose queue metadata and request correlation.
      # @limits It does not change retry behavior, acknowledge jobs, or install global error handlers.
      # @collaborators Chronos facade, JobPayload, and Sidekiq server middleware chain.
      # @thread_safety Shared instances keep only immutable collaborators.
      # @compatibility Sidekiq 4.x/5.x server middleware signature.
      # @example
      #   ServerMiddleware.new.call(worker, job, "default") { worker.perform }
      # @errors The original worker exception is always re-raised after contained notification.
      # @performance No per-job thread or connection; normalization has strict collection limits.
      class ServerMiddleware
        def initialize(options = {})
          @notifier = options[:notifier] || Chronos
          @clock = options[:clock] || proc { monotonic_time }
          @wall_clock = options[:wall_clock] || proc { Time.now.to_f }
          @limiter = options[:limiter] || JobPayload.new
        end

        def call(worker, job, queue)
          started_at = @clock.call
          payload = base_payload(worker, job, queue)
          context = execution_context(job, payload)
          @notifier.with_context(context) do
            begin
              result = yield
              finish(payload, started_at, "completed")
              result
            rescue Exception => error # rubocop:disable Lint/RescueException
              finish(payload, started_at, "failed", error)
              notify_failure(error, payload)
              raise
            end
          end
        end

        private

        def base_payload(worker, job, queue)
          source = job.is_a?(Hash) ? job : {}
          arguments, truncated = @limiter.arguments(source["args"] || source[:args])
          payload = {
            "kind" => "sidekiq", "class" => worker_class(worker, source),
            "queue" => (source["queue"] || source[:queue] || queue).to_s,
            "jid" => (source["jid"] || source[:jid]).to_s,
            "retry_count" => retry_count(source), "arguments" => arguments,
            "arguments_truncated" => truncated, "tags" => tags(worker, source),
            "queue_latency_ms" => queue_latency(source)
          }
          payload
        end

        def execution_context(job, payload)
          metadata = job.is_a?(Hash) ? (job[CONTEXT_KEY] || job[CONTEXT_KEY.to_sym]) : nil
          propagated = metadata.is_a?(Hash) ? (metadata["context"] || metadata[:context]) : nil
          propagated = {} unless propagated.is_a?(Hash)
          {
            :context => propagated.merge("job" => job_context(payload)),
            :__chronos_captured_exceptions => {}
          }
        end

        def finish(payload, started_at, status, error = nil)
          payload["duration_ms"] = [elapsed_ms(started_at), 0.0].max
          payload["status"] = status
          payload["error_class"] = error.class.name.to_s if error
          @notifier.record_event("job", payload)
        rescue StandardError
          false
        end

        def notify_failure(error, payload)
          context = {:context => {"job" => job_context(payload)},
                     :parameters => {"arguments" => payload["arguments"]}, :tags => payload["tags"]}
          if @notifier.respond_to?(:notify_once)
            @notifier.notify_once(error, context)
          else
            @notifier.notify(error, context)
          end
        rescue StandardError
          false
        end

        def job_context(payload)
          %w(kind class queue jid retry_count queue_latency_ms duration_ms status).each_with_object({}) do |key, result|
            result[key] = payload[key] unless payload[key].nil?
          end
        end

        def worker_class(worker, job)
          explicit = job["wrapped"] || job[:wrapped] || job["class"] || job[:class]
          explicit = worker.class.name if explicit.to_s.empty? && worker
          explicit.to_s
        rescue StandardError
          ""
        end

        def retry_count(job)
          value = job["retry_count"] || job[:retry_count]
          value.to_i < 0 ? 0 : value.to_i
        end

        def tags(worker, job)
          values = job["tags"] || job[:tags]
          if values.nil? && worker
            owner = worker.is_a?(Class) ? worker : worker.class
            options = owner.get_sidekiq_options if owner.respond_to?(:get_sidekiq_options)
            values = options["tags"] || options[:tags] if options.is_a?(Hash)
          end
          @limiter.tags(values)
        rescue StandardError
          []
        end

        def queue_latency(job)
          metadata = job[CONTEXT_KEY] || job[CONTEXT_KEY.to_sym]
          enqueued_at = job["enqueued_at"] || job[:enqueued_at]
          enqueued_at ||= metadata["enqueued_at"] || metadata[:enqueued_at] if metadata.is_a?(Hash)
          return nil unless enqueued_at

          [((@wall_clock.call.to_f - enqueued_at.to_f) * 1000.0).round(3), 0.0].max
        rescue StandardError
          nil
        end

        def elapsed_ms(started_at)
          ((@clock.call - started_at) * 1000.0).round(3)
        end

        def monotonic_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        rescue StandardError
          Time.now.to_f
        end
      end
    end
  end
end
