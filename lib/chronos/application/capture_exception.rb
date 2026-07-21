module Chronos
  module Application
    # Orchestrates exception normalization, serialization, queueing, and delivery.
    #
    # @responsibility Execute the exception capture pipeline for manual and integration callers.
    # @motivation Keep the public facade and transport adapters free of use-case logic.
    # @limits Framework hooks remain separate integration adapters.
    # @collaborators NoticeBuilder, PayloadSerializer, and DeliveryPipeline.
    # @thread_safety Collaborators are immutable or synchronized; calls may run concurrently.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; independent of Rails.
    # @example
    #   capture.call(exception, :user => {"id" => "42"})
    # @errors All internal StandardError failures are contained and logged.
    # @performance Local work is bounded before asynchronous queue insertion.
    class CaptureException
      def initialize(config, delivery_pipeline, logger = nil, options = {})
        @config = config
        @delivery_pipeline = delivery_pipeline
        @logger = logger || Internal::SafeLogger.new(config.logger)
        @notice_builder = options[:notice_builder] || Core::NoticeBuilder.new(config)
        @ignore_policy = options[:ignore_policy]
        @serializer = options[:serializer] || Core::PayloadSerializer.new(
          config,
          nil,
          :max_payload_size => proc { @delivery_pipeline.max_payload_size }
        )
      end

      def call(exception, context = {})
        return false unless capture_enabled?

        notice = build_notice(exception, context)
        return false if ignored?(notice)
        return false unless @delivery_pipeline.capture_allowed?("exception", notice.fingerprint)

        @delivery_pipeline.enqueue(@serializer.call(notice))
      rescue StandardError => error
        diagnose(error)
        false
      end

      def call_sync(exception, context = {})
        return false unless capture_enabled?

        notice = build_notice(exception, context)
        return false if ignored?(notice)
        return false unless @delivery_pipeline.capture_allowed?("exception", notice.fingerprint)

        @delivery_pipeline.deliver_sync(@serializer.call(notice))
      rescue StandardError => error
        diagnose(error)
        false
      end

      private

      def capture_enabled?
        @config.enabled_for_environment? && @config.error_notifications
      end

      def build_notice(exception, context)
        @notice_builder.call(exception, context)
      end

      def ignored?(notice)
        @ignore_policy && @ignore_policy.ignored?(notice)
      end

      def diagnose(error)
        @logger.warn("Chronos capture failed: #{error.class}")
      end
    end
  end
end
