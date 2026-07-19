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
    ATTRIBUTES = [
      :project_id, :project_key, :host, :environment, :app_version,
      :service_name, :root_directory, :logger, :timeout, :open_timeout,
      :queue_size, :workers, :enabled, :error_notifications,
      :ignored_environments, :proxy, :ssl_verify, :user_agent,
      :max_payload_size, :gzip
    ].freeze

    attr_accessor(*ATTRIBUTES)

    def initialize
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
    end

    def snapshot
      errors = validation_errors
      raise ConfigurationError, errors.join(", ") unless errors.empty?

      Snapshot.new(to_hash)
    end

    def valid?
      validation_errors.empty?
    end

    def validation_errors
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
      errors
    end

    private

    def to_hash
      ATTRIBUTES.each_with_object({}) do |attribute, values|
        value = public_send(attribute)
        value = value.dup if value.is_a?(Array) || value.is_a?(Hash) || value.is_a?(String)
        values[attribute] = value
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
          value.freeze if value.is_a?(Array) || value.is_a?(Hash) || value.is_a?(String)
          instance_variable_set("@#{attribute}", value)
        end
        freeze
      end

      def enabled_for_environment?
        enabled && !ignored_environments.map(&:to_s).include?(environment.to_s)
      end
    end
  end
end
