module Chronos
  # Runtime composition root for the framework-independent Chronos agent.
  #
  # @responsibility Own transport, resilient delivery pipeline, and the capture use case.
  # @motivation Keep construction details outside the public module facade.
  # @limits It does not integrate with Rails, Rack, or job systems.
  # @collaborators Configuration snapshot, CaptureException, DeliveryPipeline, and NetHttpTransport.
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
      @capture.call(exception, context)
    end

    def notify_sync(exception, context = {})
      @capture.call_sync(exception, context)
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
  end
end
