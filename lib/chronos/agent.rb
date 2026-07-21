module Chronos
  # Runtime composition root for the framework-independent Chronos agent.
  #
  # @responsibility Own delivery, capture, execution context, and breadcrumb collaborators.
  # @motivation Keep construction details outside the public module facade.
  # @limits It does not install Rack, Rails, or job integrations automatically.
  # @collaborators CaptureException, DeliveryPipeline, ContextStore, and BreadcrumbBuffer.
  # @thread_safety Runtime collaborators synchronize mutable state.
  # @compatibility Ruby 2.2.10 through Ruby 2.6.
  # @example
  #   agent.notify(RuntimeError.new("failed"))
  # @errors Capture errors return false; explicit construction requires valid configuration.
  # @performance No worker threads are created until the first asynchronous event.
  class Agent
    DEFAULT_FLUSH_TIMEOUT = 5.0

    attr_reader :config

    def initialize(config, options = {})
      @config = config
      @logger = options[:logger] || Internal::SafeLogger.new(config.logger)
      @context_store = options[:context_store] || build_context_store(config.context_store)
      unless Ports::ContextStore.compatible?(@context_store)
        raise ArgumentError, "context store does not implement the Chronos context-store port"
      end
      @transport = options[:transport] || Adapters::NetHttpTransport.new(config, @logger)
      unless Ports::Transport.compatible?(@transport)
        raise ArgumentError, "transport does not implement the Chronos transport port"
      end
      pipeline_options = {}
      pipeline_options[:queue] = options[:queue] if options[:queue]
      pipeline_options[:worker_pool] = options[:worker_pool] if options[:worker_pool]
      @delivery_pipeline = options[:delivery_pipeline] || Application::DeliveryPipeline.new(
        config,
        @transport,
        @logger,
        pipeline_options
      )
      initialize_capture(options)
      @dependency_reporter = options[:dependency_reporter] || Application::DependencyReporter.new(config)
    end

    def notify(exception, context = {})
      report_dependencies
      @capture.call(exception, context_for_capture(context))
    end

    def notify_sync(exception, context = {})
      report_dependencies
      @capture.call_sync(exception, context_for_capture(context))
    end

    def with_context(context = {}, &block)
      @context_store.with_context(context, &block)
    end

    def add_breadcrumb(attributes = {})
      context = @context_store.get
      buffer = context[:__chronos_breadcrumbs]
      buffer ||= Core::BreadcrumbBuffer.new(@config.breadcrumb_capacity, @config.breadcrumb_max_bytes)
      buffer.add(attributes)
      @context_store.set(context.merge(:__chronos_breadcrumbs => buffer))
      true
    rescue StandardError => error
      @logger.warn("Chronos breadcrumb failed: #{error.class}")
      false
    end

    def record_event(event_type, payload = {}, context = {})
      report_dependencies unless event_type.to_s == "dependencies"
      @telemetry.call(event_type, payload, telemetry_context(context))
    end

    def report_dependencies
      payload = @dependency_reporter.call
      return false unless payload

      @telemetry.call("dependencies", payload, {})
    rescue StandardError => error
      @logger.warn("Chronos dependency reporting failed: #{error.class}")
      false
    end

    def record_event_once(key, event_type, payload = {}, context = {})
      execution = @context_store.get
      captured = execution[:__chronos_captured_events] || {}
      return false if captured[key.to_s]

      captured[key.to_s] = true
      @context_store.set(execution.merge(:__chronos_captured_events => captured))
      record_event(event_type, payload, context)
    rescue StandardError
      false
    end

    def apm_integration_options
      {
        :enabled => @config.apm_enabled,
        :slow_query_threshold_ms => @config.apm_slow_query_threshold_ms,
        :root_directory => @config.root_directory
      }
    end

    def external_http_integration_options
      {:enabled => @config.external_http_enabled, :trace_headers => @config.external_http_trace_headers}
    end

    def cache_integration_options
      {:project_id => @config.project_id, :key_mode => @config.cache_key_mode}
    end

    # Returns the correlation subset safe for an integration-owned process boundary.
    def propagation_context
      current = context_hash(@context_store.get)
      nested = context_hash(current[:context] || current["context"])
      request = context_hash(nested["request"] || nested[:request])
      values = {
        "trace_id" => nested["trace_id"] || nested[:trace_id],
        "request_id" => nested["request_id"] || nested[:request_id] ||
                        request["request_id"] || request[:request_id]
      }
      values.delete_if { |_key, value| value.to_s.empty? }
    rescue StandardError
      {}
    end

    def notify_once(exception, context = {})
      execution = @context_store.get
      captured = execution[:__chronos_captured_exceptions] || {}
      keys = [[:object, exception.object_id], [:message, exception.message.to_s]]
      return false if keys.any? { |key| captured[key] }

      keys.each { |key| captured[key] = true }
      @context_store.set(execution.merge(:__chronos_captured_exceptions => captured))
      notify(exception, context)
    rescue StandardError
      false
    end

    def rails_integration_options(environment = nil, console = false)
      current_environment = (environment || @config.environment).to_s
      enabled = @config.rails_enabled
      enabled = false if console && !@config.rails_capture_in_console
      enabled = false if current_environment == "test" && !@config.rails_capture_in_test
      {:enabled => enabled, :include_user_agent => @config.rails_capture_user_agent}
    end

    def flush(timeout = DEFAULT_FLUSH_TIMEOUT)
      report_dependencies
      @telemetry.flush
      @delivery_pipeline.flush(timeout)
    rescue StandardError => error
      @logger.warn("Chronos flush failed: #{error.class}")
      false
    end

    def close(timeout = DEFAULT_FLUSH_TIMEOUT)
      report_dependencies
      @telemetry.flush
      @delivery_pipeline.close(timeout)
    rescue StandardError => error
      @logger.warn("Chronos close failed: #{error.class}")
      false
    end

    def diagnostics
      details = @delivery_pipeline.diagnostics
      details[:apm] = @telemetry.diagnostics
      details[:queue].merge(details)
    end

    private

    def initialize_capture(options)
      @capture = options[:capture] || Application::CaptureException.new(@config, @delivery_pipeline, @logger)
      @telemetry = options[:telemetry] || Application::CaptureTelemetry.new(@config, @delivery_pipeline, @logger)
    end

    def build_context_store(strategy)
      return Adapters::ThreadLocalContextStore.new if strategy == :thread_local

      strategy
    end

    def context_for_capture(additional)
      merged = deep_merge(context_hash(@context_store.get), context_hash(additional))
      merged.delete(:__chronos_captured_exceptions)
      merged.delete("__chronos_captured_exceptions")
      merged.delete(:__chronos_captured_events)
      merged.delete("__chronos_captured_events")
      buffer = merged.delete(:__chronos_breadcrumbs) || merged.delete("__chronos_breadcrumbs")
      if buffer.respond_to?(:to_a)
        merged[:context] = context_hash(merged[:context]).merge("breadcrumbs" => buffer.to_a)
      end
      merged
    rescue StandardError
      context_hash(additional)
    end

    def telemetry_context(additional)
      merged = context_for_capture(additional)
      context = context_hash(merged.delete(:context) || merged.delete("context"))
      parameters = merged.delete(:parameters) || merged.delete("parameters")
      user = merged.delete(:user) || merged.delete("user")
      context["parameters"] = parameters if parameters.is_a?(Hash) && !parameters.empty?
      context["user"] = user if user.is_a?(Hash) && !user.empty?
      context.merge(merged)
    end

    def deep_merge(left, right)
      left.merge(right) do |_key, old_value, new_value|
        old_value.is_a?(Hash) && new_value.is_a?(Hash) ? deep_merge(old_value, new_value) : new_value
      end
    end

    def context_hash(value)
      value.is_a?(Hash) ? value : {}
    end
  end
end
