module Chronos
  module Application
    # Orchestrates exception normalization, serialization, queueing, and delivery.
    #
    # @responsibility Execute the version 0.2 exception capture pipeline.
    # @motivation Keep the public facade and transport adapters free of use-case logic.
    # @limits It does not implement sampling, retry, backlog, or framework hooks.
    # @collaborators NoticeBuilder, PayloadSerializer, WorkerPool, and Transport.
    # @thread_safety Collaborators are immutable or synchronized; calls may run concurrently.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; independent of Rails.
    # @example
    #   capture.call(exception, :user => {"id" => "42"})
    # @errors All internal StandardError failures are contained and logged.
    # @performance Local work is bounded before asynchronous queue insertion.
    class CaptureException
      def initialize(config, worker_pool, transport, logger = nil, options = {})
        @config = config
        @worker_pool = worker_pool
        @transport = transport
        @logger = logger || Internal::SafeLogger.new(config.logger)
        @notice_builder = options[:notice_builder] || Core::NoticeBuilder.new(config)
        @serializer = options[:serializer] || Core::PayloadSerializer.new(config)
      end

      def call(exception, context = {})
        return false unless capture_enabled?

        event = build_event(exception, context)
        @worker_pool.enqueue(event)
      rescue StandardError => error
        diagnose(error)
        false
      end

      def call_sync(exception, context = {})
        return false unless capture_enabled?

        event = build_event(exception, context)
        @transport.send_event(event).success?
      rescue StandardError => error
        diagnose(error)
        false
      end

      private

      def capture_enabled?
        @config.enabled_for_environment? && @config.error_notifications
      end

      def build_event(exception, context)
        notice = @notice_builder.call(exception, context)
        @serializer.call(notice)
      end

      def diagnose(error)
        @logger.warn("Chronos capture failed: #{error.class}")
      end
    end
  end
end
