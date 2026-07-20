require "uri"

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
    DEFAULT_BLOCKLIST_KEYS = %w(
      password password_confirmation passwd secret api_key apikey authorization
      token access_token refresh_token private_key client_secret cookie set-cookie
      session credit_card card_number cvv cpf cnpj
    ).freeze
    CONTEXT_STORE_METHODS = [:get, :set, :clear, :with_context].freeze

    ATTRIBUTES = [
      :project_id, :project_key, :host, :environment, :app_version,
      :service_name, :root_directory, :logger, :timeout, :open_timeout,
      :queue_size, :workers, :enabled, :error_notifications,
      :ignored_environments, :proxy, :ssl_verify, :user_agent,
      :max_payload_size, :gzip, :blocklist_keys, :allowlist_keys,
      :filters, :hash_keys, :anonymize_ip, :max_retries,
      :retry_base_interval, :retry_max_interval, :retry_jitter,
      :backlog_size, :circuit_failure_threshold, :circuit_reset_timeout,
      :remote_configuration, :remote_config_max_bytes, :sampling_rate,
      :enabled_event_types, :max_remote_send_interval, :context_store,
      :breadcrumb_capacity, :breadcrumb_max_bytes
    ].freeze

    attr_accessor(*ATTRIBUTES)

    def initialize
      initialize_core_defaults
      initialize_privacy_defaults
      initialize_resilience_defaults
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

    def initialize_privacy_defaults
      @blocklist_keys = DEFAULT_BLOCKLIST_KEYS.dup
      @allowlist_keys = []
      @filters = []
      @hash_keys = []
      @anonymize_ip = true
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
      @enabled_event_types = ["exception"]
      @max_remote_send_interval = 60.0
    end

    def resilience_errors
      errors = []
      errors.concat(retry_errors)
      errors.concat(backlog_and_circuit_errors)
      errors.concat(remote_policy_errors)
      errors
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
      unless [true, false].include?(remote_configuration)
        errors << "remote_configuration must be true or false"
      end
      errors << "remote_config_max_bytes must be a positive integer" unless positive_integer?(remote_config_max_bytes)
      errors << "sampling_rate must be between zero and one" unless rate?(sampling_rate)
      unless enabled_event_types.is_a?(Array) && enabled_event_types.all? { |value| value.is_a?(String) }
        errors << "enabled_event_types must contain only String values"
      end
      errors << "max_remote_send_interval must be greater than zero" unless positive_number?(max_remote_send_interval)
      errors
    end

    def to_hash
      ATTRIBUTES.each_with_object({}) do |attribute, values|
        value = public_send(attribute)
        values[attribute] = deep_copy(value)
      end
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
      errors.concat(anonymization_errors)
      errors
    end

    def context_errors
      errors = []
      unless context_store == :thread_local || CONTEXT_STORE_METHODS.all? do |method_name|
        context_store.respond_to?(method_name)
      end
        errors << "context_store must be :thread_local or implement get, set, clear, and with_context"
      end
      errors << "breadcrumb_capacity must be a positive integer" unless positive_integer?(breadcrumb_capacity)
      unless breadcrumb_max_bytes.is_a?(Integer) && breadcrumb_max_bytes >= 128
        errors << "breadcrumb_max_bytes must be an integer greater than or equal to 128"
      end
      errors
    end

    def filter_errors
      return ["filters must be an array"] unless filters.is_a?(Array)
      return [] if filters.all? { |filter| filter.respond_to?(:call) }

      ["filters must contain only callable objects"]
    end

    def anonymization_errors
      return [] if anonymize_ip == true || anonymize_ip == false

      ["anonymize_ip must be true or false"]
    end

    def matcher_errors(name, values)
      return [] unless values.is_a?(Array)
      return [] if values.all? { |value| value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(Regexp) }

      ["#{name} must contain only String, Symbol, or Regexp values"]
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

    def host_errors
      return ["host is required"] if blank?(host)

      uri = URI.parse(host.to_s)
      return ["host must be an absolute HTTP or HTTPS URL"] unless uri.host && %w(http https).include?(uri.scheme)
      return ["host must use HTTPS unless ssl_verify is explicitly disabled"] if uri.scheme != "https" && ssl_verify

      []
    rescue URI::InvalidURIError
      ["host must be a valid URL"]
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

    # Immutable configuration shared by all runtime components.
    #
    # @responsibility Expose validated settings without mutable containers.
    # @motivation Keep capture behavior stable while multiple threads run.
    # @limits It cannot be edited after creation.
    # @thread_safety Safe to share between threads after construction.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    class Snapshot
      attr_reader(*ATTRIBUTES)

      def initialize(values)
        ATTRIBUTES.each do |attribute|
          value = values[attribute]
          deep_freeze(value)
          instance_variable_set("@#{attribute}", value)
        end
        freeze
      end

      def enabled_for_environment?
        enabled && !ignored_environments.map(&:to_s).include?(environment.to_s)
      end

      private

      def deep_freeze(value)
        return value if value.respond_to?(:call) || context_store?(value)

        case value
        when Hash
          value.each do |key, child|
            deep_freeze(key)
            deep_freeze(child)
          end
        when Array
          value.each { |child| deep_freeze(child) }
        end
        value.freeze
      end

      def context_store?(value)
        CONTEXT_STORE_METHODS.all? { |method_name| value.respond_to?(method_name) }
      rescue StandardError
        false
      end
    end
  end
end
