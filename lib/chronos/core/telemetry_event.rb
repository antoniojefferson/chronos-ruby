require "securerandom"
require "time"

module Chronos
  module Core
    # Immutable framework telemetry event normalized to the Chronos v1 envelope.
    #
    # @responsibility Carry a bounded event type, timestamp, context, and payload.
    # @motivation Let integrations report metrics without depending on exception notices.
    # @limits It does not sanitize, serialize, enqueue, or deliver itself.
    # @collaborators TelemetrySerializer and framework integrations.
    # @thread_safety Immutable after construction and safe to share.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   event = Chronos::Core::TelemetryEvent.new("request", {"duration_ms" => 12.0})
    # @errors Unsupported types raise ArgumentError during construction.
    # @performance Construction is linear in supplied context and payload size.
    class TelemetryEvent
      TYPES = %w(request query job cache external_http dependencies deploy metric_batch).freeze

      attr_reader :event_id, :event_type, :timestamp, :context, :payload

      def initialize(event_type, payload = {}, context = {}, options = {})
        type = event_type.to_s
        raise ArgumentError, "unsupported telemetry event type" unless TYPES.include?(type)

        clock = options[:clock] || proc { Time.now }
        @event_id = (options[:event_id] || SecureRandom.uuid).to_s.freeze
        @event_type = type.freeze
        @timestamp = clock.call.utc.iso8601(6).freeze
        @context = deep_freeze(context.is_a?(Hash) ? context : {})
        @payload = deep_freeze(payload.is_a?(Hash) ? payload : {})
        freeze
      end

      private

      def deep_freeze(value)
        if value.is_a?(Hash)
          value.each do |key, child|
            deep_freeze(key)
            deep_freeze(child)
          end
        elsif value.is_a?(Array)
          value.each { |child| deep_freeze(child) }
        end
        value.freeze
      end
    end

    # Serializes framework telemetry into the common Chronos event envelope.
    #
    # @responsibility Sanitize telemetry, normalize JSON primitives, and enforce payload size.
    # @motivation Give Rails subscribers the same privacy and delivery boundary as exceptions.
    # @limits It accepts only TelemetryEvent values and does not perform delivery.
    # @collaborators TelemetryEvent, Sanitizer, SafeSerializer, RuntimeInfo, and SerializedEvent.
    # @thread_safety Stateless apart from immutable configuration.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   serialized = serializer.call(event)
    # @errors Oversized events raise Chronos::Error and are contained by CaptureTelemetry.
    # @performance Traversal and output bytes are bounded by existing serializer budgets.
    class TelemetrySerializer
      def initialize(config, clock = nil, options = {})
        @config = config
        @clock = clock || proc { Time.now }
        @sanitizer = options[:sanitizer] || Sanitizer.new(config)
        @safe_serializer = options[:safe_serializer] || SafeSerializer.new
        @max_payload_size = options[:max_payload_size] || proc { @config.max_payload_size }
        @runtime_info = RuntimeInfo.new
        @correlation = options[:correlation] || CorrelationContext.new(config)
      end

      def call(event)
        raise ArgumentError, "event must be a TelemetryEvent" unless event.is_a?(TelemetryEvent)

        envelope = @safe_serializer.call(@sanitizer.call(build_envelope(event)))
        body = JSON.generate(envelope)
        body = JSON.generate(compact_envelope(envelope)) if body.bytesize > @max_payload_size.call
        raise Error, "event exceeds max_payload_size" if body.bytesize > @max_payload_size.call

        SerializedEvent.new(event.event_id, body)
      end

      private

      def build_envelope(event)
        runtime = @runtime_info.call
        {
          "schema_version" => "1.0", "event_id" => event.event_id,
          "event_type" => event.event_type, "occurred_at" => event.timestamp,
          "sent_at" => @clock.call.utc.iso8601(6), "project_key" => @config.project_id,
          "environment" => event_environment(event),
          "service" => event_service(event, runtime),
          "correlation" => event_correlation(event, runtime),
          "runtime" => runtime[:runtime], "context" => event.context, "payload" => event.payload
        }
      end

      def event_environment(event)
        event.event_type == "deploy" ? event.payload["environment"] : @config.environment
      end

      def event_service(event, runtime)
        deploy = event.event_type == "deploy" ? event.payload : {}
        {
          "name" => deploy["service"] || @config.service_name,
          "version" => deploy["version"] || @config.app_version,
          "instance_id" => deploy["instance"] || @config.instance_id || runtime[:host]
        }
      end

      def event_correlation(event, runtime)
        overrides = {"instance" => @config.instance_id || runtime[:host]}
        if event.event_type == "deploy"
          overrides.merge!(
            "release" => event.payload["version"], "revision" => event.payload["revision"],
            "deploy_id" => event.payload["deploy_id"], "environment" => event.payload["environment"],
            "service" => event.payload["service"], "region" => event.payload["region"],
            "instance" => event.payload["instance"]
          )
        end
        @correlation.call(overrides)
      end

      def compact_envelope(envelope)
        envelope["context"] = {"_truncated" => true}
        envelope["payload"] = {"_truncated" => true}
        envelope
      end
    end
  end
end
