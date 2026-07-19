module Chronos
  # Runtime composition root for the framework-independent Chronos agent.
  #
  # @responsibility Own transport, queue, workers, and the capture use case.
  # @motivation Keep construction details outside the public module facade.
  # @limits It does not integrate with Rails, Rack, or job systems.
  # @collaborators Configuration snapshot, CaptureException, BoundedQueue, and NetHttpTransport.
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
      @queue = options[:queue] || Internal::BoundedQueue.new(config.queue_size)
      @worker_pool = options[:worker_pool] || Internal::WorkerPool.new(@queue, @transport, config.workers, @logger)
      @capture = options[:capture] || Application::CaptureException.new(config, @worker_pool, @transport, @logger)
    end

    def notify(exception, context = {})
      @capture.call(exception, context)
    end

    def notify_sync(exception, context = {})
      @capture.call_sync(exception, context)
    end

    def flush(timeout = DEFAULT_FLUSH_TIMEOUT)
      @worker_pool.flush(timeout)
    rescue StandardError => error
      @logger.warn("Chronos flush failed: #{error.class}")
      false
    end

    def close(timeout = DEFAULT_FLUSH_TIMEOUT)
      @worker_pool.close(timeout)
    rescue StandardError => error
      @logger.warn("Chronos close failed: #{error.class}")
      false
    end

    def diagnostics
      @queue.stats
    end
  end
end
