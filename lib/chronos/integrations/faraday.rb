module Chronos
  module Integrations
    # Optional Faraday middleware for outbound timing and W3C propagation.
    # @responsibility Instrument one explicit Faraday connection without global patches.
    # @motivation Modern Rails applications commonly use Faraday for outbound HTTP.
    # @limits It never reads paths, queries, headers other than trace fields, or bodies.
    # @collaborators Faraday middleware stack, TraceContext, and Chronos facade.
    # @thread_safety Calls retain request state in local variables.
    # @compatibility Faraday 1.x and 2.x middleware contracts.
    # @example builder.use Chronos::Integrations::FaradayMiddleware
    # @errors Original client exceptions are recorded by class and re-raised.
    # @performance Two clock reads and one bounded asynchronous event per request.
    class FaradayMiddleware
      def initialize(app, options = {})
        @app = app
        @notifier = options[:notifier] || Chronos
        @clock = options[:clock] || proc { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      end

      def call(environment)
        started_at = @clock.call
        inject_headers(environment)
        response = @app.call(environment)
        if response.respond_to?(:on_complete)
          response.on_complete { |completed| record(completed, started_at, nil) }
        else
          record(environment, started_at, nil)
        end
        response
      rescue StandardError => error
        record(environment, started_at, error) if started_at
        raise
      end

      private

      def inject_headers(environment)
        options = integration_options
        return unless options[:trace_headers] && environment.respond_to?(:request_headers)

        context = @notifier.respond_to?(:propagation_context) ? @notifier.propagation_context : {}
        headers = environment.request_headers
        traceparent = Core::TraceContext.format(context) if options[:w3c_trace_context]
        headers["traceparent"] ||= traceparent if traceparent
        headers["X-Chronos-Trace-ID"] ||= context["trace_id"] if context["trace_id"]
        headers["X-Chronos-Request-ID"] ||= context["request_id"] if context["request_id"]
      rescue StandardError
        nil
      end

      def record(environment, started_at, error)
        url = environment.url if environment.respond_to?(:url)
        payload = {
          "host" => (url.host.to_s if url && url.respond_to?(:host)),
          "method" => (environment.method.to_s.upcase if environment.respond_to?(:method)),
          "status" => (environment.status.to_i if environment.respond_to?(:status) && environment.status),
          "duration_ms" => ((@clock.call - started_at) * 1000.0).round(3),
          "error_class" => (error.class.name.to_s if error)
        }
        payload.delete_if { |_key, value| value.nil? || value == "" }
        @notifier.record_event("external_http", payload)
      rescue StandardError
        false
      end

      def integration_options
        return {:enabled => true, :trace_headers => true, :w3c_trace_context => false} unless
          @notifier.respond_to?(:external_http_integration_options)

        @notifier.external_http_integration_options
      rescue StandardError
        {:enabled => false, :trace_headers => false, :w3c_trace_context => false}
      end
    end
  end
end
