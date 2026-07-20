require "securerandom"

module Chronos
  module Integrations
    module Rack
      # Captures unhandled Rack exceptions while preserving Rack semantics.
      #
      # @responsibility Build bounded request context, notify Chronos, and re-raise the original exception.
      # @motivation Provide automatic error capture without coupling the core to Rack.
      # @limits It never reads rack.input, enumerates response bodies, or infers Rails routes.
      # @collaborators Rack application and the Chronos facade or Agent.
      # @thread_safety Shared instances keep no per-request mutable state.
      # @compatibility Rack 1.x/2.x protocol; Ruby 2.2.10 through Ruby 2.6.
      # @example
      #   use Chronos::Integrations::Rack::Middleware
      # @errors Notification failures are contained; the application exception is always re-raised.
      # @performance Adds bounded hash construction and monotonic-clock reads per request.
      class Middleware
        def initialize(app, options = {})
          @app = app
          @notifier = options[:notifier] || Chronos
          @include_user_agent = options[:include_user_agent] || false
          @clock = options[:clock] || proc { monotonic_time }
        end

        def call(env)
          started_at = @clock.call
          base = request_capture_context(env)
          @notifier.with_context(base) do
            add_request_breadcrumb("request started", base)
            call_application(env, base, started_at)
          end
        end

        private

        def call_application(env, base, started_at)
          response = @app.call(env)
          status = response[0]
          headers = response[1]
          add_request_breadcrumb("request completed", dynamic_request_context(base, status, headers, started_at))
          response
        rescue Exception => error # rubocop:disable Lint/RescueException
          context = dynamic_request_context(base, 500, nil, started_at)
          notify_safely(error, context)
          raise
        end

        def notify_safely(error, context)
          if @notifier.respond_to?(:notify_once)
            @notifier.notify_once(error, context)
          else
            @notifier.notify(error, context)
          end
        rescue StandardError
          false
        end

        def request_capture_context(env)
          request = request_values(env)
          {
            :context => {"request" => request, "trace_id" => trace_id(env)},
            :parameters => parameters(env),
            :user => hash_value(env["chronos.user"])
          }
        end

        def request_values(env)
          values = {
            "method" => env["REQUEST_METHOD"].to_s,
            "route" => normalized_route(env),
            "request_id" => request_id(env),
            "host" => (env["HTTP_HOST"] || env["SERVER_NAME"]).to_s,
            "path" => env["PATH_INFO"].to_s,
            "controller" => controller_action(env, "controller"),
            "action" => controller_action(env, "action")
          }
          values["user_agent"] = env["HTTP_USER_AGENT"].to_s if @include_user_agent
          values
        end

        def dynamic_request_context(base, status, headers, started_at)
          request = base[:context]["request"].merge(
            "status" => status.to_i,
            "duration_ms" => ((@clock.call - started_at) * 1000.0).round(3),
            "response_size" => response_size(headers)
          )
          {:context => base[:context].merge("request" => request)}
        end

        def parameters(env)
          result = {}
          [env["rack.request.query_hash"], env["action_dispatch.request.query_parameters"],
           env["action_dispatch.request.path_parameters"], env["chronos.parameters"]].each do |candidate|
            result.merge!(candidate) if candidate.is_a?(Hash)
          end
          result
        rescue StandardError
          {}
        end

        def normalized_route(env)
          explicit = env["chronos.route"] || env["action_dispatch.route_uri_pattern"]
          return explicit.to_s unless explicit.to_s.empty?

          env["PATH_INFO"].to_s.split("/").map { |part| dynamic_segment?(part) ? ":id" : part }.join("/")
        end

        def dynamic_segment?(segment)
          segment =~ /\A\d+\z/ || segment =~ /\A[0-9a-f]{8}-[0-9a-f-]{27,}\z/i
        end

        def controller_action(env, key)
          explicit = env["chronos.#{key}"]
          paths = env["action_dispatch.request.path_parameters"]
          explicit || (paths[key] if paths.is_a?(Hash)) || (paths[key.to_sym] if paths.is_a?(Hash))
        end

        def request_id(env)
          env["chronos.request_id"] || env["action_dispatch.request_id"] || env["HTTP_X_REQUEST_ID"]
        end

        def trace_id(env)
          env["chronos.trace_id"] || SecureRandom.uuid
        end

        def response_size(headers)
          return nil unless headers.respond_to?(:each)

          pair = headers.find { |key, _value| key.to_s.casecmp("content-length").zero? }
          pair ? pair[1].to_i : nil
        rescue StandardError
          nil
        end

        def add_request_breadcrumb(message, context)
          request = context[:context]["request"]
          @notifier.add_breadcrumb(
            :category => "request", :message => message,
            :metadata => {"method" => request["method"], "route" => request["route"], "status" => request["status"]}
          )
        end

        def hash_value(value)
          value.is_a?(Hash) ? value : {}
        end

        def monotonic_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        rescue StandardError
          Time.now.to_f
        end
      end
    end
  end
end
