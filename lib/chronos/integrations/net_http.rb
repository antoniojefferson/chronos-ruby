module Chronos
  module Integrations
    # Optional per-instance Net::HTTP instrumentation without a global monkey patch.
    #
    # @responsibility Install one idempotent request wrapper on an explicit HTTP connection.
    # @motivation Legacy Net::HTTP has no middleware callback but must remain safe and optional.
    # @limits Class convenience methods and uninstrumented instances are deliberately untouched.
    # @collaborators Net::HTTP-compatible connection, request objects, and Chronos notifier.
    # @thread_safety Installation is synchronized per object; request state is call-local.
    # @compatibility Net::HTTP on Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   Chronos::Integrations::NetHttp.install(Net::HTTP.new("api.example.com"))
    # @errors Instrumentation errors are contained; original HTTP errors are re-raised unchanged.
    # @performance Adds bounded hashes and clock reads; never reads request/response bodies.
    module NetHttp
      INSTALLED_KEY = :@__chronos_net_http_installed
      OPTIONS_KEY = :@__chronos_net_http_options

      class << self
        def install(connection, options = {})
          notifier = options[:notifier] || Chronos
          return false unless enabled?(notifier)
          return false unless connection.respond_to?(:request) && connection.respond_to?(:address)

          mutex_for(connection).synchronize do
            return false if connection.instance_variable_get(INSTALLED_KEY)

            connection.instance_variable_set(OPTIONS_KEY, instrumentation_options(notifier, options))
            connection.singleton_class.send(:prepend, InstrumentedRequest)
            connection.instance_variable_set(INSTALLED_KEY, true)
          end
          true
        rescue StandardError
          false
        end

        private

        def enabled?(notifier)
          return true unless notifier.respond_to?(:external_http_integration_options)

          notifier.external_http_integration_options[:enabled] == true
        rescue StandardError
          false
        end

        def instrumentation_options(notifier, options)
          configured = if notifier.respond_to?(:external_http_integration_options)
                         notifier.external_http_integration_options
                       else
                         {}
                       end
          {
            :notifier => notifier,
            :clock => options[:clock] || proc { monotonic_time },
            :trace_headers => configured.fetch(:trace_headers, true)
          }
        end

        def mutex_for(connection)
          key = :@__chronos_net_http_mutex
          connection.instance_variable_get(key) || connection.instance_variable_set(key, Mutex.new)
        end

        def monotonic_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        rescue StandardError
          Time.now.to_f
        end
      end

      # Request wrapper prepended only to an explicitly selected HTTP object.
      #
      # @responsibility Inject bounded trace headers and record outcome/timing around `request`.
      # @motivation Preserve the native API, streaming block, and exception semantics.
      # @limits It never reads URL path/query, Authorization, request body, headers, or response body.
      # @collaborators NetHttp installation options and Chronos record_event.
      # @thread_safety All request observations use local variables.
      # @compatibility Net::HTTP#request signature on Ruby 2.2.10 through Ruby 2.6.
      # @example
      #   connection.request(Net::HTTP::Get.new("/health"))
      # @errors Original StandardError values are recorded by class and re-raised unchanged.
      # @performance Two clock reads and one asynchronous telemetry observation per call.
      module InstrumentedRequest
        def request(request, body = nil, &block)
          options = instance_variable_get(NetHttp::OPTIONS_KEY)
          started_at = options[:clock].call
          inject_trace_headers(request, options) if options[:trace_headers]
          response = super(request, body, &block)
          record_external_http(options, request, started_at, response, nil)
          response
        rescue StandardError => error
          record_external_http(options, request, started_at, nil, error) if options && started_at
          raise
        end

        private

        def inject_trace_headers(request, options)
          return unless request.respond_to?(:[]) && request.respond_to?(:[]=)

          context = if options[:notifier].respond_to?(:propagation_context)
                      options[:notifier].propagation_context
                    else
                      {}
                    end
          set_header(request, "X-Chronos-Trace-ID", context["trace_id"] || context[:trace_id])
          set_header(request, "X-Chronos-Request-ID", context["request_id"] || context[:request_id])
        rescue StandardError
          nil
        end

        def set_header(request, name, value)
          request[name] = value.to_s if request[name].to_s.empty? && !value.to_s.empty?
        end

        def record_external_http(options, request, started_at, response, error)
          payload = {
            "host" => sanitized_external_host,
            "method" => request.respond_to?(:method) ? request.method.to_s.upcase : "",
            "status" => response_status(response),
            "duration_ms" => ((options[:clock].call - started_at) * 1000.0).round(3),
            "timeout" => timeout_error?(error),
            "connection_error" => connection_error?(error),
            "error_class" => error ? error.class.name.to_s : ""
          }
          payload.delete_if { |_key, value| value.nil? || value == "" }
          options[:notifier].record_event("external_http", payload)
        rescue StandardError
          false
        end

        def response_status(response)
          response.code.to_i if response && response.respond_to?(:code)
        end

        def sanitized_external_host
          host = respond_to?(:address) ? address.to_s.downcase.sub(/\.\z/, "") : ""
          host = host.scrub("?") if host.respond_to?(:scrub)
          host.bytesize > 253 ? host.byteslice(0, 253) : host
        rescue StandardError
          ""
        end

        def timeout_error?(error)
          return false unless error

          error.is_a?(Timeout::Error) || !error.class.name.to_s.match(/Timeout/).nil?
        rescue StandardError
          false
        end

        def connection_error?(error)
          return false unless error
          return false if timeout_error?(error)

          error.is_a?(SystemCallError) || error.is_a?(IOError) ||
            !error.class.name.to_s.match(/SocketError|OpenSSL::SSL::SSLError/).nil?
        rescue StandardError
          false
        end
      end
    end
  end
end
