require "uri"
require "chronos/configuration/validation"
require "chronos/configuration/apm_validation"

module Chronos
  # Mutable configuration used only while the Chronos agent is being set up.
  #
  # @responsibility Store options, validate them,
  #   and create immutable snapshots.
  # @motivation Prevent runtime components
  #   from observing partially changed state.
  # @limits It does not send events or read application environment variables.
  # @collaborators Chronos::Configuration::Snapshot.
  # @thread_safety Configure one instance
  #   from one thread before sharing its snapshot.
  # @compatibility Ruby 2.2.10 through Ruby 2.6.
  # @example
  #   config = Chronos::Configuration.new
  #   config.project_id = 'project-id'
  #   config.project_key = 'project-key'
  #   config.host = 'https://chronos.example.com'
  #   snapshot = config.snapshot
  class Configuration
    include Internal::ConfigurationValidation
    include Internal::ApmConfigurationValidation
    DEFAULT_BLOCKLIST_KEYS = %w(
      password password_confirmation passwd secret api_key apikey authorization
      token access_token refresh_token private_key client_secret cookie set-cookie
      session credit_card card_number cvv cpf cnpj
    ).freeze
    CONTEXT_STORE_METHODS = [:get, :set, :clear, :with_context].freeze

    ATTRIBUTES = [
      :project_id, :project_key, :host, :environment, :app_version,
      :service_name, :revision, :deploy_id, :region, :instance_id,
      :root_directory, :logger, :timeout, :open_timeout,
      :queue_size, :workers, :enabled, :error_notifications,
      :ignored_environments, :proxy, :ssl_verify, :user_agent,
      :max_payload_size, :gzip, :blocklist_keys, :allowlist_keys,
      :filters, :hash_keys, :anonymize_ip, :ignore_rules, :max_ignore_rules, :max_retries,
      :retry_base_interval, :retry_max_interval, :retry_jitter,
      :backlog_size, :circuit_failure_threshold, :circuit_reset_timeout,
      :remote_configuration, :remote_config_max_bytes, :sampling_rate,
      :enabled_event_types, :max_remote_send_interval, :context_store,
      :breadcrumb_capacity, :breadcrumb_max_bytes, :rails_enabled,
      :rails_capture_in_console, :rails_capture_in_test, :rails_capture_user_agent,
      :apm_enabled, :apm_max_groups, :apm_flush_count, :apm_batch_size,
      :apm_max_queries_per_request, :apm_slow_query_threshold_ms,
      :apm_long_transaction_threshold_ms, :apm_n_plus_one_threshold,
      :apm_histogram_buckets, :external_http_enabled, :external_http_trace_headers,
      :cache_key_mode, :dependency_reporting, :dependency_max_items
    ].freeze

    attr_accessor(*ATTRIBUTES)

    def initialize
      initialize_core_defaults
      initialize_privacy_defaults
      initialize_resilience_defaults
      initialize_rails_defaults
      initialize_apm_defaults
      initialize_observability_defaults
      initialize_correlation_defaults
    end

    def snapshot
      errors = validation_errors
      raise ConfigurationError, errors.join(", ") unless errors.empty?

      Snapshot.new(to_hash)
    end

    def valid?
      validation_errors.empty?
    end

    def validation_errors # rubocop:disable Metrics/AbcSize
      errors = []
      if enabled
        errors << "project_id is required" if blank?(project_id)
        errors << "project_key is required" if blank?(project_key)
        errors.concat(host_errors)
      end
      errors << "timeout must be greater than zero" unless positive_number?(timeout)
      errors << "open_timeout must be greater than zero" unless positive_number?(open_timeout)
      errors << "queue_size must be a positive integer" unless positive_integer?(queue_size)
      errors << "workers must be a positive integer" unless positive_integer?(workers)
      errors << "max_payload_size must be a positive integer" unless positive_integer?(max_payload_size)
      errors.concat(resilience_errors)
      errors.concat(privacy_errors)
      errors.concat(context_errors)
      errors.concat(apm_errors)
      errors.concat(observability_errors)
      errors
    end

    private

    def initialize_core_defaults
      @project_id = nil
      @project_key = nil
      @host = nil
      @environment = "production"
      @app_version = nil
      @service_name = nil
      @root_directory = Dir.pwd
      @logger = nil
      @timeout = 5.0
      @open_timeout = 2.0
      @queue_size = 100
      @workers = 1
      @enabled = true
      @error_notifications = true
      @ignored_environments = []
      @proxy = nil
      @ssl_verify = true
      @user_agent = "chronos-ruby/#{Chronos::VERSION}"
      @max_payload_size = 1_048_576
      @gzip = false
      @context_store = :thread_local
      @breadcrumb_capacity = 20
      @breadcrumb_max_bytes = 2048
    end

    def initialize_correlation_defaults
      @revision = nil
      @deploy_id = nil
      @region = nil
      @instance_id = nil
    end

    def initialize_rails_defaults
      @rails_enabled = true
      @rails_capture_in_console = false
      @rails_capture_in_test = false
      @rails_capture_user_agent = false
    end

    def initialize_apm_defaults
      @apm_enabled = true
      @apm_max_groups = 200
      @apm_flush_count = 100
      @apm_batch_size = 50
      @apm_max_queries_per_request = 100
      @apm_slow_query_threshold_ms = 500.0
      @apm_long_transaction_threshold_ms = 1000.0
      @apm_n_plus_one_threshold = 5
      @apm_histogram_buckets = [5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0, 2500.0, 5000.0]
    end

    def initialize_observability_defaults
      @external_http_enabled = false
      @external_http_trace_headers = true
      @cache_key_mode = :none
      @dependency_reporting = true
      @dependency_max_items = 100
    end

    def initialize_privacy_defaults
      @blocklist_keys = DEFAULT_BLOCKLIST_KEYS.dup
      @allowlist_keys = []
      @filters = []
      @hash_keys = []
      @anonymize_ip = true
      @ignore_rules = []
      @max_ignore_rules = 20
    end

    def initialize_resilience_defaults
      @max_retries = 3
      @retry_base_interval = 0.5
      @retry_max_interval = 30.0
      @retry_jitter = 0.25
      @backlog_size = 100
      @circuit_failure_threshold = 5
      @circuit_reset_timeout = 30.0
      @remote_configuration = true
      @remote_config_max_bytes = 4096
      @sampling_rate = 1.0
      @enabled_event_types = [
        "exception", "request", "query", "job", "cache", "external_http", "dependencies", "deploy", "metric_batch"
      ]
      @max_remote_send_interval = 60.0
    end

    def to_hash
      ATTRIBUTES.each_with_object({}) do |attribute, values|
        value = public_send(attribute)
        values[attribute] = deep_copy(value)
      end
    end

    def deep_copy(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, child), result| result[deep_copy(key)] = deep_copy(child) }
      when Array
        value.map { |child| deep_copy(child) }
      when String, Regexp
        value.dup
      else
        value
      end
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def positive_number?(value)
      value.is_a?(Numeric) && value > 0
    end

    def positive_integer?(value)
      value.is_a?(Integer) && value > 0
    end

    def non_negative_integer?(value)
      value.is_a?(Integer) && value >= 0
    end

    def rate?(value)
      value.is_a?(Numeric) && value >= 0.0 && value <= 1.0
    end
  end
end

require "chronos/configuration/snapshot"
