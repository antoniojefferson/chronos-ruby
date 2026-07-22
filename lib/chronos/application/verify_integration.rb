require "securerandom"

module Chronos
  module Application
    # Sends and verifies one synthetic exception against the configured Chronos receiver.
    #
    # @responsibility Build an identified test notice, deliver it synchronously, and validate its acknowledgement.
    # @motivation Verify credentials and end-to-end ingestion without mistaking an empty 2xx for confirmation.
    # @limits It exposes only allowlisted project/receiver fields and never returns raw server responses.
    # @collaborators NoticeBuilder, PayloadSerializer, DeliveryPipeline, and IntegrationVerificationResult.
    # @thread_safety Calls allocate independent IDs and immutable results; collaborators synchronize delivery.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; independent of Rails.
    # @example
    #   result = verifier.call
    #   result.success? #=> true or false
    # @errors Network, protocol, configuration, and receiver failures become structured results.
    # @performance Performs one bounded synchronous verification plus configured bounded retries.
    class VerifyIntegration
      SCHEMA_VERSION = "1.0".freeze
      VERIFICATION_KIND = "integration_verification".freeze
      VERIFICATION_TAG = "chronos-integration-verification".freeze

      def initialize(config, delivery_pipeline, logger = nil, options = {})
        @config = config
        @delivery_pipeline = delivery_pipeline
        @logger = logger || Internal::SafeLogger.new(config.logger)
        @uuid_generator = options[:uuid_generator] || proc { SecureRandom.uuid }
        @notice_builder = options[:notice_builder] || Core::NoticeBuilder.new(config)
        @serializer = options[:serializer] || Core::PayloadSerializer.new(
          config,
          nil,
          :max_payload_size => proc { @delivery_pipeline.max_payload_size }
        )
      end

      def call
        verification_id = bounded(@uuid_generator.call, 128)
        return local_failure("configuration_invalid", verification_id, configuration_guidance) unless configured?

        event = build_event(verification_id)
        transport_result = @delivery_pipeline.deliver_sync_result(event)
        classify(transport_result, verification_id, event.event_id)
      rescue StandardError => error
        @logger.warn("Chronos integration verification failed: #{error.class}")
        local_failure("verification_failed", verification_id, "Review the Chronos configuration and retry.")
      end

      private

      def configured?
        !@config.project_id.to_s.empty? && !@config.project_key.to_s.empty? && !@config.host.to_s.empty?
      end

      def build_event(verification_id)
        marker = {
          "schema_version" => SCHEMA_VERSION,
          "verification_id" => verification_id,
          "kind" => VERIFICATION_KIND,
          "test" => true
        }
        notice = @notice_builder.call(
          IntegrationVerificationError.new("Chronos integration verification test"),
          :severity => "info",
          :context => {"integration_verification" => marker},
          :tags => [VERIFICATION_TAG],
          :fingerprint => VERIFICATION_TAG
        )
        @serializer.call(notice)
      end

      def classify(result, verification_id, event_id)
        return classify_success(result.response, verification_id, event_id) if result.success?
        if inactive_response?(result, verification_id, event_id)
          return project_inactive(result.response, verification_id, event_id)
        end
        return invalid_credentials(verification_id, event_id) if [401, 403].include?(result.status_code)
        return rate_limited(verification_id, event_id) if result.status == :rate_limited
        return receiver_unavailable(verification_id, event_id) if unavailable?(result)
        return receiver_internal_error(verification_id, event_id) if result.status == :server_error

        request_rejected(verification_id, event_id)
      end

      def classify_success(response, verification_id, event_id)
        unless valid_acknowledgement?(response, verification_id, event_id)
          return failure("invalid_response", verification_id, event_id,
                         :receiver_status => "reachable",
                         :message => "Chronos returned a response outside the verification contract.",
                         :guidance => "Update Chronos to the integration verification response v1 contract.")
        end

        Core::IntegrationVerificationResult.new(
          :success => true,
          :status => "verified",
          :verification_id => verification_id,
          :credentials_valid => true,
          :event => {"id" => event_id, "received" => true},
          :project => safe_project(response["project"]),
          :receiver => safe_receiver(response["receiver"]),
          :error => nil
        )
      end

      def valid_acknowledgement?(response, verification_id, event_id)
        valid_response_structure?(response) &&
          acknowledgement_matches?(response, verification_id, event_id) &&
          active_project?(response["project"]) && operational_receiver?(response["receiver"])
      end

      def valid_response_structure?(response)
        exact_keys?(response, %w(
                      schema_version success status verification_id credentials_valid event_received
                      event project receiver error
                    )) &&
          exact_keys?(response["event"], %w(id)) &&
          exact_keys?(response["project"], %w(id name status environment)) &&
          exact_keys?(response["receiver"], %w(name status received_at))
      end

      def acknowledgement_matches?(response, verification_id, event_id)
        response["schema_version"] == SCHEMA_VERSION && response["verification_id"] == verification_id &&
          response["status"] == "accepted" && response["success"] == true &&
          response["credentials_valid"] == true && response["event_received"] == true &&
          hash_value(response["event"])["id"] == event_id && response["error"].nil?
      end

      def active_project?(project)
        hash_value(project)["id"] == @config.project_id.to_s && hash_value(project)["status"] == "active"
      end

      def operational_receiver?(receiver)
        hash_value(receiver)["status"] == "operational"
      end

      def inactive_response?(result, verification_id, event_id)
        response = result.response
        result.status_code == 403 && valid_response_structure?(response) &&
          inactive_state?(response) && inactive_correlation?(response, verification_id, event_id)
      end

      def inactive_state?(response)
        response["schema_version"] == SCHEMA_VERSION && response["success"] == false &&
          response["status"] == "project_inactive" && response["credentials_valid"] == true &&
          response["event_received"] == false && hash_value(response["project"])["status"] == "inactive" &&
          valid_error?(response["error"])
      end

      def inactive_correlation?(response, verification_id, event_id)
        response["verification_id"] == verification_id && hash_value(response["event"])["id"] == event_id &&
          hash_value(response["project"])["id"] == @config.project_id.to_s
      end

      def valid_error?(error)
        exact_keys?(error, %w(code message guidance)) && error["code"] == "project_inactive"
      end

      def project_inactive(response, verification_id, event_id)
        failure("project_inactive", verification_id, event_id,
                :credentials_valid => true, :receiver_status => "reachable",
                :message => "The Chronos project is inactive and did not accept the verification event.",
                :guidance => "Activate the project in Chronos or select an active project, then retry.",
                :project => safe_project(response["project"]))
      end

      def invalid_credentials(verification_id, event_id)
        failure("invalid_credentials", verification_id, event_id,
                :credentials_valid => false, :receiver_status => "reachable",
                :message => "Chronos rejected the project credentials.",
                :guidance => "Create an active project API key, then confirm project_id and project_key.")
      end

      def rate_limited(verification_id, event_id)
        failure("rate_limited", verification_id, event_id,
                :receiver_status => "reachable",
                :message => "Chronos temporarily rate limited the verification request.",
                :guidance => "Wait before retrying and review the project ingestion limits.")
      end

      def receiver_internal_error(verification_id, event_id)
        failure("receiver_internal_error", verification_id, event_id,
                :receiver_status => "error",
                :message => "Chronos encountered an internal error while processing the verification.",
                :guidance => "Retry later or contact the Chronos operator with the verification_id.")
      end

      def receiver_unavailable(verification_id, event_id)
        failure("receiver_unavailable", verification_id, event_id,
                :receiver_status => "unavailable",
                :message => "The Chronos receiver is unavailable or could not be reached.",
                :guidance => "Check the host, DNS, TLS, network access, and Chronos service status.")
      end

      def request_rejected(verification_id, event_id)
        failure("request_rejected", verification_id, event_id,
                :receiver_status => "reachable",
                :message => "Chronos rejected the integration verification request.",
                :guidance => "Confirm that the gem and Chronos support the verification v1 contract.")
      end

      def unavailable?(result)
        [:network_error, :request_timeout, :circuit_open].include?(result.status) ||
          [502, 503, 504].include?(result.status_code)
      end

      def failure(status, verification_id, event_id, options = {})
        Core::IntegrationVerificationResult.new(
          :success => false,
          :status => status,
          :verification_id => verification_id,
          :credentials_valid => options[:credentials_valid],
          :event => {"id" => event_id, "received" => false},
          :project => options[:project],
          :receiver => {"name" => "chronos", "status" => options[:receiver_status], "received_at" => nil},
          :error => {"code" => status, "message" => options[:message], "guidance" => options[:guidance]}
        )
      end

      def local_failure(status, verification_id, guidance)
        failure(status, verification_id, nil,
                :receiver_status => "not_checked",
                :message => "Chronos integration verification could not be started.",
                :guidance => guidance)
      end

      def configuration_guidance
        "Configure a non-empty project_id, project_key, and HTTPS host before running verification."
      end

      def safe_project(value)
        safe_fields(value, "id" => 128, "name" => 128, "status" => 32, "environment" => 128)
      end

      def safe_receiver(value)
        safe_fields(value, "name" => 64, "status" => 32, "received_at" => 64)
      end

      def safe_fields(value, fields)
        source = hash_value(value)
        fields.each_with_object({}) do |(name, limit), result|
          result[name] = source[name].nil? ? nil : bounded(source[name], limit)
        end
      end

      def hash_value(value)
        value.is_a?(Hash) ? value : {}
      end

      def exact_keys?(value, keys)
        value.is_a?(Hash) && value.keys.sort == keys.sort
      end

      def bounded(value, limit)
        text = value.to_s.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "?")
        return text if text.bytesize <= limit

        text.byteslice(0, limit).to_s.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "?")
      rescue StandardError
        ""
      end
    end
  end
end
