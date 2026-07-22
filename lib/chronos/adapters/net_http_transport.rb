require "net/http"
require "openssl"
require "json"
require "stringio"
require "uri"
require "zlib"

module Chronos
  module Adapters
    # Net::HTTP implementation of the Chronos transport port.
    #
    # @responsibility Send serialized events over bounded HTTPS requests.
    # @motivation Use the Ruby standard library to preserve legacy compatibility.
    # @limits It classifies failures but leaves retry and backlog policy to the application layer.
    # @collaborators Configuration::Snapshot, SerializedEvent, and TransportResult.
    # @thread_safety Creates a new Net::HTTP connection per call and synchronizes health state.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; no Rails dependency.
    # @example
    #   result = transport.send_event(serialized_event)
    # @errors Network, TLS, and HTTP errors are returned, never raised to callers.
    # @performance One bounded network request per delivery attempt in version 0.3.
    class NetHttpTransport
      EVENT_PATH = "/api/v1/events".freeze
      REMOTE_CONFIGURATION_HEADER = "X-Chronos-Remote-Configuration".freeze
      RESPONSE_BODY_MAX_BYTES = 8192

      def initialize(config, logger = nil)
        @config = config
        @logger = logger || Internal::SafeLogger.new(config.logger)
        @health_mutex = Mutex.new
        @healthy = true
        @closed = false
      end

      def send_event(event)
        return Ports::TransportResult.new(:closed) if closed?

        response = perform_request(event)
        result = classify(response)
        update_health(result.success?)
        result
      rescue StandardError => error
        update_health(false)
        @logger.warn("Chronos transport failed: #{error.class}")
        Ports::TransportResult.new(:network_error, :error => error.class.name)
      end

      def send_batch(events)
        Array(events).map { |event| send_event(event) }
      end

      def healthy?
        @health_mutex.synchronize { @healthy && !@closed }
      end

      def close
        @health_mutex.synchronize { @closed = true }
        true
      end

      private

      def perform_request(event)
        uri = endpoint_uri
        http = build_http(uri)
        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"
        request["User-Agent"] = @config.user_agent
        request["X-Chronos-Project-ID"] = @config.project_id.to_s
        request["X-Chronos-Project-Key"] = @config.project_key.to_s
        request["Idempotency-Key"] = event.event_id
        request.body = request_body(event.body)
        request["Content-Encoding"] = "gzip" if @config.gzip
        http.start do |connection|
          connection.request(request) do |response|
            read_bounded_response(response)
          end
        end
      end

      def endpoint_uri
        uri = URI.parse(@config.host)
        base_path = uri.path.to_s.sub(%r{/+\z}, "")
        uri.path = base_path + EVENT_PATH
        uri.query = nil
        uri.fragment = nil
        uri
      end

      def build_http(uri)
        http = if @config.proxy
                 proxy = URI.parse(@config.proxy)
                 Net::HTTP::Proxy(proxy.host, proxy.port, proxy.user, proxy.password).new(uri.host, uri.port)
               else
                 Net::HTTP.new(uri.host, uri.port)
               end
        http.open_timeout = @config.open_timeout
        http.read_timeout = @config.timeout
        if uri.scheme == "https"
          http.use_ssl = true
          http.verify_mode = @config.ssl_verify ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        end
        http
      end

      def classify(response)
        code = response.code.to_i
        options = {:status_code => code, :response => parse_response(response)}
        if code >= 200 && code < 300
          options[:remote_configuration] = parse_remote_configuration(response)
          return Ports::TransportResult.new(:success, options)
        end
        return Ports::TransportResult.new(:request_timeout, options) if code == 408
        if code == 429
          options[:retry_after] = response["Retry-After"]
          return Ports::TransportResult.new(:rate_limited, options)
        end
        return Ports::TransportResult.new(:server_error, options) if code >= 500

        Ports::TransportResult.new(:client_error, options)
      end

      def read_bounded_response(response)
        body = ""
        overflow = false
        response.read_body do |chunk|
          next if overflow

          remaining = RESPONSE_BODY_MAX_BYTES - body.bytesize
          if chunk.bytesize > remaining
            overflow = true
          else
            body << chunk
          end
        end
        response.instance_variable_set(:@chronos_response_body, overflow ? nil : body)
      end

      def parse_response(response)
        content_type = response["Content-Type"].to_s.split(";", 2).first
        return nil unless content_type == "application/json"

        body = response.instance_variable_get(:@chronos_response_body)
        return nil if body.nil? || body.empty?

        parsed = JSON.parse(body)
        parsed.is_a?(Hash) ? parsed : nil
      rescue JSON::ParserError, EncodingError
        nil
      end

      def parse_remote_configuration(response)
        return nil unless @config.remote_configuration

        value = response[REMOTE_CONFIGURATION_HEADER]
        return nil if value.nil? || value.bytesize > @config.remote_config_max_bytes

        parsed = JSON.parse(value)
        parsed.is_a?(Hash) ? parsed : nil
      rescue JSON::ParserError, EncodingError
        nil
      end

      def request_body(body)
        return body unless @config.gzip

        output = StringIO.new
        writer = Zlib::GzipWriter.new(output)
        writer.write(body)
        writer.close
        output.string
      end

      def update_health(value)
        @health_mutex.synchronize { @healthy = value }
      end

      def closed?
        @health_mutex.synchronize { @closed }
      end
    end
  end
end
