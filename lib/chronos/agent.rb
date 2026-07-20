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
      @capture = options[:capture] || Application::CaptureException.new(config, @delivery_pipeline, @logger)
    end

    def notify(exception, context = {})
      @capture.call(exception, context_for_capture(context))
    end

    def notify_sync(exception, context = {})
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

    def flush(timeout = DEFAULT_FLUSH_TIMEOUT)
      @delivery_pipeline.flush(timeout)
    rescue StandardError => error
      @logger.warn("Chronos flush failed: #{error.class}")
      false
    end

    def close(timeout = DEFAULT_FLUSH_TIMEOUT)
      @delivery_pipeline.close(timeout)
    rescue StandardError => error
      @logger.warn("Chronos close failed: #{error.class}")
      false
    end

    def diagnostics
      details = @delivery_pipeline.diagnostics
      details[:queue].merge(details)
    end

    private

    def build_context_store(strategy)
      return Adapters::ThreadLocalContextStore.new if strategy == :thread_local

      strategy
    end

    def context_for_capture(additional)
      merged = deep_merge(context_hash(@context_store.get), context_hash(additional))
      buffer = merged.delete(:__chronos_breadcrumbs) || merged.delete("__chronos_breadcrumbs")
      if buffer.respond_to?(:to_a)
        merged[:context] = context_hash(merged[:context]).merge("breadcrumbs" => buffer.to_a)
      end
      merged
    rescue StandardError
      context_hash(additional)
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
