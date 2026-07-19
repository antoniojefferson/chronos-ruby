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
    # @responsibility Normalize values to JSON primitives and enforce size limits.
    # @motivation Prevent arbitrary application objects or invalid encodings from breaking capture.
    # @limits Version 0.1 applies structural limits, not the advanced privacy rules from 0.2.
    # @collaborators Notice and SerializedEvent.
    # @thread_safety Stateless apart from immutable configuration.
    # @compatibility Uses the JSON standard library available on Ruby 2.2.10.
    # @example
    #   event = serializer.call(notice)
    #   event.body #=> "{...}"
    # @errors Serialization failures are handled by CaptureException.
    # @performance Linear in payload size with bounded depth and collection sizes.
    class PayloadSerializer
      MAX_DEPTH = 10
      MAX_KEYS = 100
      MAX_ITEMS = 100
      MAX_STRING_BYTES = 8192

      def initialize(config, clock = nil)
        @config = config
        @clock = clock || proc { Time.now }
      end

      def call(notice)
        envelope = build_envelope(notice)
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
          "project_key" => safe_string(@config.project_id),
          "environment" => safe_string(notice.environment),
          "service" => {
            "name" => safe_string(@config.service_name),
            "version" => safe_string(@config.app_version),
            "instance_id" => safe_string(notice.host)
          },
          "runtime" => normalize(notice.runtime, 0),
          "context" => normalize(notice.context, 0),
          "payload" => payload(notice)
        }
      end

      def payload(notice)
        normalize({
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
                  }, 0)
      end

      def compact_envelope(envelope)
        payload = envelope["payload"]
        exception = payload["exception"]
        exception["message"] = truncate_string(exception["message"], 1024)
        exception["backtrace"] = Array(exception["backtrace"]).first(20)
        payload["parameters"] = {"_truncated" => true}
        payload["session"] = {"_truncated" => true}
        payload["user"] = {"_truncated" => true}
        envelope["context"] = {"_truncated" => true}
        envelope
      end

      def normalize(value, depth)
        return "<maximum depth reached>" if depth >= MAX_DEPTH

        case value
        when nil, true, false, Integer
          value
        when Float
          value.finite? ? value : value.to_s
        when String, Symbol
          truncate_string(safe_string(value), MAX_STRING_BYTES)
        when Array
          value.first(MAX_ITEMS).map { |child| normalize(child, depth + 1) }
        when Hash
          normalize_hash(value, depth)
        else
          "<#{safe_class_name(value)}>"
        end
      rescue StandardError
        "<unserializable value>"
      end

      def normalize_hash(value, depth)
        result = {}
        value.to_a.first(MAX_KEYS).each do |key, child|
          result[truncate_string(safe_string(key), 256)] = normalize(child, depth + 1)
        end
        result
      end

      def safe_string(value)
        return nil if value.nil?

        value.to_s.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "�")
      rescue StandardError
        "<unreadable value>"
      end

      def truncate_string(value, limit)
        return value if value.nil? || value.bytesize <= limit

        value.byteslice(0, limit).to_s.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "�") + "…"
      end

      def safe_class_name(value)
        value.class.name.to_s
      rescue StandardError
        "Object"
      end
    end
  end
end
