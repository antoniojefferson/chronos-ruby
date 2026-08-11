module Chronos
  module Integrations
    # Optional, dependency-free bridge to an already configured OpenTelemetry SDK.
    module OpenTelemetry
      module_function

      def current_context
        return {} unless defined?(::OpenTelemetry::Trace) && ::OpenTelemetry::Trace.respond_to?(:current_span)

        span = ::OpenTelemetry::Trace.current_span
        context = span.context if span && span.respond_to?(:context)
        return {} unless context && (!context.respond_to?(:valid?) || context.valid?)

        trace_id = hex_identifier(context, :hex_trace_id, :trace_id, 32)
        span_id = hex_identifier(context, :hex_span_id, :span_id, 16)
        return {} if trace_id.empty? || span_id.empty?

        {"trace_id" => trace_id, "span_id" => span_id,
         "trace_flags" => sampled?(context) ? "01" : "00", "source" => "opentelemetry"}
      rescue StandardError
        {}
      end

      def active?
        !current_context.empty?
      end

      def hex_identifier(context, hex_method, numeric_method, width)
        value = context.public_send(hex_method) if context.respond_to?(hex_method)
        value ||= context.public_send(numeric_method).to_i.to_s(16) if context.respond_to?(numeric_method)
        value.to_s.downcase.rjust(width, "0")[-width, width]
      rescue StandardError
        ""
      end

      def sampled?(context)
        flags = context.trace_flags if context.respond_to?(:trace_flags)
        flags.respond_to?(:sampled?) ? flags.sampled? : flags.to_i.odd?
      rescue StandardError
        false
      end
    end
  end
end
