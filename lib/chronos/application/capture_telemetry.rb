module Chronos
  module Application
    # Coordinates bounded non-exception telemetry capture.
    #
    # @responsibility Build, sanitize, serialize, and enqueue integration events.
    # @motivation Keep Rails notification policy outside transport and domain objects.
    # @limits It handles request, query, job, and cache events only.
    # @collaborators TelemetryEvent, TelemetrySerializer, and DeliveryPipeline.
    # @thread_safety Calls own event state and may execute concurrently.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; independent of Rails.
    # @example
    #   capture.call("query", {"duration_ms" => 3.2})
    # @errors Internal StandardError failures are contained and logged.
    # @performance Local normalization is bounded before asynchronous queue insertion.
    class CaptureTelemetry
      def initialize(config, delivery_pipeline, logger = nil, options = {})
        @config = config
        @delivery_pipeline = delivery_pipeline
        @logger = logger || Internal::SafeLogger.new(config.logger)
        @serializer = options[:serializer] || Core::TelemetrySerializer.new(
          config, nil, :max_payload_size => proc { @delivery_pipeline.max_payload_size }
        )
      end

      def call(event_type, payload = {}, context = {})
        return false unless @config.enabled_for_environment?
        return false unless @delivery_pipeline.capture_allowed?(event_type)

        event = Core::TelemetryEvent.new(event_type, payload, context)
        @delivery_pipeline.enqueue(@serializer.call(event))
      rescue StandardError => error
        @logger.warn("Chronos telemetry capture failed: #{error.class}")
        false
      end
    end
  end
end
