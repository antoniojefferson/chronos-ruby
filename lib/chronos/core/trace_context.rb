module Chronos
  module Core
    # Parses and formats the W3C Trace Context headers without an OpenTelemetry dependency.
    module TraceContext
      TRACEPARENT = /\A([\da-f]{2})-([\da-f]{32})-([\da-f]{16})-([\da-f]{2})\z/.freeze

      module_function

      def parse(value)
        match = TRACEPARENT.match(value.to_s.downcase)
        return {} unless match && match[1] == "00"
        return {} if match[2] == ("0" * 32) || match[3] == ("0" * 16)

        {"trace_id" => match[2], "span_id" => match[3], "trace_flags" => match[4]}
      rescue StandardError
        {}
      end

      def format(context)
        trace_id = value(context, "trace_id")
        span_id = value(context, "span_id")
        flags = value(context, "trace_flags")
        return nil unless trace_id =~ /\A[\da-f]{32}\z/ && span_id =~ /\A[\da-f]{16}\z/
        return nil if trace_id == ("0" * 32) || span_id == ("0" * 16)

        "00-#{trace_id}-#{span_id}-#{flags =~ /\A[\da-f]{2}\z/ ? flags : '01'}"
      rescue StandardError
        nil
      end

      def value(context, key)
        return "" unless context.is_a?(Hash)

        (context[key] || context[key.to_sym]).to_s.downcase
      end
    end
  end
end
