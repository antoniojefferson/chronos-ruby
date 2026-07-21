module Chronos
  module Internal
    # Validates bounded APM aggregation, histogram, and detector settings.
    #
    # @responsibility Return configuration errors for version 0.7 APM options.
    # @motivation Keep the general configuration validator focused and maintainable.
    # @limits It validates shape and bounds but does not allocate aggregator state.
    # @collaborators Chronos::Configuration predicates and attributes.
    # @thread_safety Reads one mutable configuration instance without shared state.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @errors Invalid values become messages and never raise from validation.
    module ApmConfigurationValidation
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
        errors
      end

      def increasing_positive_numbers?(values)
        return false unless values.is_a?(Array) && !values.empty? && values.length <= 19
        return false unless values.all? { |value| positive_number?(value) }

        values.each_cons(2).all? { |left, right| right > left }
      end
    end
  end
end
