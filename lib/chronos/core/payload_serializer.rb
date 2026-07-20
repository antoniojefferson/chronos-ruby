require "json"
require "time"

module Chronos
  module Core
    # Serialized event ready for transport.
    #
    # @responsibility Keep an event ID next to its JSON body.
    # @motivation Allow transports to set idempotency headers without reparsing JSON.
    # @limits It contains no retry or HTTP behavior.
    # @thread_safety Immutable after construction.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    class SerializedEvent
      attr_reader :event_id, :body

      def initialize(event_id, body)
        @event_id = event_id.to_s.freeze
        @body = body.to_s.freeze
        freeze
      end

      def bytesize
        body.bytesize
      end
    end

    # Converts a Notice into the versioned Chronos JSON envelope.
    #
    # @responsibility Sanitize an event, normalize it to JSON primitives, and enforce size limits.
    # @motivation Ensure sensitive or unsafe application values never reach transport unchanged.
    # @limits Detection is bounded and does not replace application-specific data governance.
    # @collaborators Notice, Sanitizer, SafeSerializer, and SerializedEvent.
    # @thread_safety Stateless apart from immutable configuration.
    # @compatibility Uses the JSON standard library available on Ruby 2.2.10.
    # @example
    #   event = serializer.call(notice)
    #   event.body #=> "{...}"
    # @errors Serialization failures are handled by CaptureException.
    # @performance Linear in payload size with bounded depth, nodes, and collection sizes.
    class PayloadSerializer
      def initialize(config, clock = nil, options = {})
        @config = config
        @clock = clock || proc { Time.now }
        @sanitizer = options[:sanitizer] || Sanitizer.new(config)
        @safe_serializer = options[:safe_serializer] || SafeSerializer.new
      end

      def call(notice)
        envelope = @safe_serializer.call(@sanitizer.call(build_envelope(notice)))
        body = JSON.generate(envelope)
        body = JSON.generate(compact_envelope(envelope)) if body.bytesize > @config.max_payload_size
        raise Error, "event exceeds max_payload_size" if body.bytesize > @config.max_payload_size

        SerializedEvent.new(notice.event_id, body)
      end

      private

      def build_envelope(notice)
        {
          "schema_version" => "1.0",
          "event_id" => notice.event_id,
          "event_type" => "exception",
          "occurred_at" => notice.timestamp,
          "sent_at" => @clock.call.utc.iso8601(6),
          "project_key" => @config.project_id,
          "environment" => notice.environment,
          "service" => {
            "name" => @config.service_name,
            "version" => @config.app_version,
            "instance_id" => notice.host
          },
          "runtime" => notice.runtime,
          "context" => notice.context,
          "payload" => payload(notice)
        }
      end

      def payload(notice)
        {
          "exception" => {
            "class" => notice.exception_class,
            "message" => notice.message,
            "backtrace" => notice.backtrace,
            "causes" => notice.causes
          },
          "severity" => notice.severity,
          "parameters" => notice.parameters,
          "session" => notice.session,
          "user" => notice.user,
          "versions" => notice.versions,
          "host" => notice.host,
          "process" => notice.process,
          "thread" => notice.thread,
          "tags" => notice.tags,
          "fingerprint" => notice.fingerprint
        }
      end

      def compact_envelope(envelope)
        payload = envelope["payload"]
        exception = payload["exception"]
        exception["message"] = @safe_serializer.call(exception["message"], :max_string_bytes => 1024)
        exception["backtrace"] = Array(exception["backtrace"]).first(20)
        payload["parameters"] = {"_truncated" => true}
        payload["session"] = {"_truncated" => true}
        payload["user"] = {"_truncated" => true}
        envelope["context"] = {"_truncated" => true}
        envelope
      end
    end
  end
end
