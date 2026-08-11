module Chronos
  module Internal
    # Validates bounded APM aggregation, histogram, and detector settings.
    #
    # @responsibility Return configuration errors for bounded APM and observability options.
    # @motivation Keep the general configuration validator focused and maintainable.
    # @limits It validates shape and bounds but does not allocate aggregator state.
    # @collaborators Chronos::Configuration predicates and attributes.
    # @thread_safety Reads one mutable configuration instance without shared state.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @errors Invalid values become messages and never raise from validation.
    module ApmConfigurationValidation # rubocop:disable Metrics/ModuleLength
      private

      def apm_errors
        errors = apm_capacity_errors
        errors.concat(apm_threshold_errors)
        errors << "apm_enabled must be true or false" unless [true, false].include?(apm_enabled)
        unless increasing_positive_numbers?(apm_histogram_buckets)
          errors << "apm_histogram_buckets must contain increasing positive numbers"
        end
        errors
      end

      def apm_capacity_errors
        errors = []
        errors << "apm_max_groups must be a positive integer" unless positive_integer?(apm_max_groups)
        errors << "apm_flush_count must be a positive integer" unless positive_integer?(apm_flush_count)
        unless apm_batch_size.is_a?(Integer) && apm_batch_size >= 1 && apm_batch_size <= 50
          errors << "apm_batch_size must be between 1 and 50"
        end
        unless positive_integer?(apm_max_queries_per_request)
          errors << "apm_max_queries_per_request must be a positive integer"
        end
        errors.concat(query_capacity_errors)
        errors
      end

      def query_capacity_errors
        errors = []
        unless apm_query_analysis_max_queries.is_a?(Integer) &&
               apm_query_analysis_max_queries >= 1 && apm_query_analysis_max_queries <= 500
          errors << "apm_query_analysis_max_queries must be between 1 and 500"
        end
        unless apm_query_inspection_max_queries.is_a?(Integer) &&
               apm_query_inspection_max_queries >= 1 && apm_query_inspection_max_queries <= 100
          errors << "apm_query_inspection_max_queries must be between 1 and 100"
        end
        unless apm_transaction_max_connections.is_a?(Integer) &&
               apm_transaction_max_connections >= 1 && apm_transaction_max_connections <= 500
          errors << "apm_transaction_max_connections must be between 1 and 500"
        end
        errors
      end

      def apm_threshold_errors
        errors = []
        unless positive_number?(apm_slow_query_threshold_ms)
          errors << "apm_slow_query_threshold_ms must be greater than zero"
        end
        unless positive_number?(apm_long_transaction_threshold_ms)
          errors << "apm_long_transaction_threshold_ms must be greater than zero"
        end
        unless apm_n_plus_one_threshold.is_a?(Integer) && apm_n_plus_one_threshold >= 2
          errors << "apm_n_plus_one_threshold must be an integer greater than or equal to 2"
        end
        errors.concat(query_threshold_errors)
        errors
      end

      def query_threshold_errors
        errors = []
        unless positive_number?(apm_trace_ttl_seconds)
          errors << "apm_trace_ttl_seconds must be greater than zero"
        end
        unless non_negative_number?(apm_query_inspection_min_duration_ms)
          errors << "apm_query_inspection_min_duration_ms must be zero or greater"
        end
        query_analysis_boolean_attributes.each do |name, value|
          errors << "#{name} must be true or false" unless boolean?(value)
        end
        if (apm_query_statistics_enabled || apm_query_plan_enabled) && !apm_query_inspection_enabled
          errors << "query statistics and plans require apm_query_inspection_enabled"
        end
        errors
      end

      def query_analysis_boolean_attributes
        {
          :apm_query_analysis_enabled => apm_query_analysis_enabled,
          :apm_query_inspection_enabled => apm_query_inspection_enabled,
          :apm_query_statistics_enabled => apm_query_statistics_enabled,
          :apm_query_plan_enabled => apm_query_plan_enabled,
          :apm_transaction_tracking_enabled => apm_transaction_tracking_enabled
        }
      end

      def non_negative_number?(value)
        value.is_a?(Numeric) && value >= 0
      end

      def increasing_positive_numbers?(values)
        return false unless values.is_a?(Array) && !values.empty? && values.length <= 19
        return false unless values.all? { |value| positive_number?(value) }

        values.each_cons(2).all? { |left, right| right > left }
      end

      def observability_errors
        errors = []
        errors << "external_http_enabled must be true or false" unless boolean?(external_http_enabled)
        errors << "external_http_trace_headers must be true or false" unless boolean?(external_http_trace_headers)
        errors << "w3c_trace_context must be true or false" unless boolean?(w3c_trace_context)
        errors << "opentelemetry_bridge must be true or false" unless boolean?(opentelemetry_bridge)
        errors << "cache_key_mode must be :none or :sha256" unless [:none, :sha256].include?(cache_key_mode)
        errors << "dependency_reporting must be true or false" unless boolean?(dependency_reporting)
        unless dependency_max_items.is_a?(Integer) && dependency_max_items >= 1 && dependency_max_items <= 200
          errors << "dependency_max_items must be between 1 and 200"
        end
        correlation_attributes.each do |name, value|
          errors << "#{name} must be a String with at most 128 bytes" unless bounded_optional_string?(value, 128)
        end
        errors
      end

      def correlation_attributes
        {:revision => revision, :deploy_id => deploy_id, :region => region, :instance_id => instance_id}
      end

      def bounded_optional_string?(value, limit)
        value.nil? || (value.is_a?(String) && value.bytesize <= limit)
      end

      def boolean?(value)
        [true, false].include?(value)
      end
    end
  end
end
