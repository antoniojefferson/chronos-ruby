module Chronos
  module Application
    # Coordinates bounded non-exception telemetry capture.
    #
    # @responsibility Aggregate APM observations or serialize and enqueue integration events.
    # @motivation Keep framework policy and local batching outside transport and domain objects.
    # @limits It handles only the event types declared by TelemetryEvent.
    # @collaborators ApmAggregator, TelemetryEvent, TelemetrySerializer, and DeliveryPipeline.
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
        @aggregator = options[:aggregator] || ApmAggregator.new(config)
      end

      def call(event_type, payload = {}, context = {})
        return false unless @config.enabled_for_environment?
        return false unless @delivery_pipeline.capture_allowed?(event_type)

        aggregate = aggregation_enabled?
        batches = aggregate ? @aggregator.record(event_type, payload, context) : []
        return enqueue_batches(batches) if aggregate && aggregate_type?(event_type)

        event = Core::TelemetryEvent.new(event_type, payload, context)
        delivered = @delivery_pipeline.enqueue(@serializer.call(event))
        enqueue_batches(batches)
        delivered
      rescue StandardError => error
        @logger.warn("Chronos telemetry capture failed: #{error.class}")
        false
      end

      def flush
        enqueue_batches(@aggregator.flush)
      rescue StandardError => error
        @logger.warn("Chronos APM flush failed: #{error.class}")
        false
      end

      def diagnostics
        @aggregator.diagnostics
      rescue StandardError
        {}
      end

      private

      def aggregate_type?(event_type)
        ApmAggregator::METRIC_TYPES.include?(event_type.to_s)
      end

      def aggregation_enabled?
        @config.apm_enabled && @delivery_pipeline.event_enabled?("metric_batch")
      end

      def enqueue_batches(batches)
        results = Array(batches).map do |batch|
          next false unless @delivery_pipeline.event_enabled?("metric_batch")

          event = Core::TelemetryEvent.new("metric_batch", batch)
          @delivery_pipeline.enqueue(@serializer.call(event))
        end
        results.empty? || results.all?
      end
    end
  end
end
