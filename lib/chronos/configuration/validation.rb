module Chronos
  module Internal
    # Shared validation predicates for mutable Chronos configuration.
    #
    # @responsibility Validate resilience, privacy, context, Rails, and endpoint settings.
    # @motivation Keep Configuration focused on option storage and snapshot creation.
    # @limits It is mixed into Configuration and is not a public extension API.
    # @collaborators Chronos::Configuration values.
    # @thread_safety Validation reads one configuration instance without shared state.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @errors Invalid values become messages; malformed URLs are contained.
    module ConfigurationValidation # rubocop:disable Metrics/ModuleLength
      private

      def resilience_errors
        retry_errors + backlog_and_circuit_errors + remote_policy_errors
      end

      def retry_errors
        errors = []
        errors << "max_retries must be a non-negative integer" unless non_negative_integer?(max_retries)
        errors << "retry_base_interval must be greater than zero" unless positive_number?(retry_base_interval)
        errors << "retry_max_interval must be greater than zero" unless positive_number?(retry_max_interval)
        if positive_number?(retry_base_interval) && positive_number?(retry_max_interval) &&
           retry_max_interval < retry_base_interval
          errors << "retry_max_interval must be greater than or equal to retry_base_interval"
        end
        errors << "retry_jitter must be between zero and one" unless rate?(retry_jitter)
        errors
      end

      def backlog_and_circuit_errors
        errors = []
        errors << "backlog_size must be a non-negative integer" unless non_negative_integer?(backlog_size)
        unless positive_integer?(circuit_failure_threshold)
          errors << "circuit_failure_threshold must be a positive integer"
        end
        errors << "circuit_reset_timeout must be greater than zero" unless positive_number?(circuit_reset_timeout)
        errors
      end

      def remote_policy_errors
        errors = []
        errors << "remote_configuration must be true or false" unless [true, false].include?(remote_configuration)
        errors << "remote_config_max_bytes must be a positive integer" unless positive_integer?(remote_config_max_bytes)
        errors << "sampling_rate must be between zero and one" unless rate?(sampling_rate)
        unless enabled_event_types.is_a?(Array) && enabled_event_types.all? { |value| value.is_a?(String) }
          errors << "enabled_event_types must contain only String values"
        end
        errors << "max_remote_send_interval must be greater than zero" unless positive_number?(max_remote_send_interval)
        errors
      end

      def privacy_errors
        errors = []
        errors << "blocklist_keys must be an array" unless blocklist_keys.is_a?(Array)
        errors << "allowlist_keys must be an array" unless allowlist_keys.is_a?(Array)
        errors << "hash_keys must be an array" unless hash_keys.is_a?(Array)
        errors.concat(matcher_errors("blocklist_keys", blocklist_keys))
        errors.concat(matcher_errors("allowlist_keys", allowlist_keys))
        errors.concat(matcher_errors("hash_keys", hash_keys))
        errors.concat(filter_errors)
        errors.concat(ignore_rule_errors)
        errors.concat(anonymization_errors)
        errors
      end

      def context_errors
        errors = []
        unless context_store == :thread_local || compatible_context_store?
          errors << "context_store must be :thread_local or implement get, set, clear, and with_context"
        end
        errors << "breadcrumb_capacity must be a positive integer" unless positive_integer?(breadcrumb_capacity)
        unless breadcrumb_max_bytes.is_a?(Integer) && breadcrumb_max_bytes >= 128
          errors << "breadcrumb_max_bytes must be an integer greater than or equal to 128"
        end
        rails_boolean_errors.each { |error| errors << error }
        errors
      end

      def compatible_context_store?
        self.class::CONTEXT_STORE_METHODS.all? { |method_name| context_store.respond_to?(method_name) }
      end

      def rails_boolean_errors
        names = [:rails_enabled, :rails_capture_in_console, :rails_capture_in_test, :rails_capture_user_agent]
        names.reject { |name| [true, false].include?(public_send(name)) }.map do |name|
          "#{name} must be true or false"
        end
      end

      def filter_errors
        return ["filters must be an array"] unless filters.is_a?(Array)
        return [] if filters.all? { |filter| filter.respond_to?(:call) }

        ["filters must contain only callable objects"]
      end

      def anonymization_errors
        [true, false].include?(anonymize_ip) ? [] : ["anonymize_ip must be true or false"]
      end

      def ignore_rule_errors
        errors = []
        unless ignore_rules.is_a?(Array) && ignore_rules.all? { |rule| rule.respond_to?(:call) }
          errors << "ignore_rules must contain only callable objects"
        end
        unless positive_integer?(max_ignore_rules) && max_ignore_rules <= 100
          errors << "max_ignore_rules must be an integer between 1 and 100"
        end
        if ignore_rules.is_a?(Array) && max_ignore_rules.is_a?(Integer) && ignore_rules.length > max_ignore_rules
          errors << "ignore_rules cannot exceed max_ignore_rules"
        end
        errors
      end

      def matcher_errors(name, values)
        return [] unless values.is_a?(Array)
        return [] if values.all? { |value| value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(Regexp) }

        ["#{name} must contain only String, Symbol, or Regexp values"]
      end

      def host_errors
        return ["host is required"] if blank?(host)

        uri = URI.parse(host.to_s)
        return ["host must be an absolute HTTP or HTTPS URL"] unless uri.host && %w(http https).include?(uri.scheme)
        return ["host must use HTTPS unless ssl_verify is explicitly disabled"] if uri.scheme != "https" && ssl_verify

        []
      rescue URI::InvalidURIError
        ["host must be a valid URL"]
      end
    end
  end
end
