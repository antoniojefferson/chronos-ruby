require "chronos/rails"

# Common Chronos settings. Every environment variable is optional unless your
# Chronos project requires it; omitted values fall back to safe SDK defaults.
env_boolean = lambda do |name, default|
  value = ENV[name]
  normalized = value.to_s.downcase
  next true if %w[1 true yes on].include?(normalized)
  next false if %w[0 false no off].include?(normalized)

  default
end

Chronos.configure do |config|
  # Identification and authentication
  config.project_id = ENV["CHRONOS_PROJECT_ID"]
  config.project_key = ENV["CHRONOS_PROJECT_KEY"]
  config.environment = ENV.fetch("CHRONOS_ENVIRONMENT", Rails.env.to_s)
  config.service_name = ENV["CHRONOS_SERVICE_NAME"] || Chronos::Rails.application_name
  config.app_version = ENV["CHRONOS_APP_VERSION"]
  config.revision = ENV["CHRONOS_REVISION"]

  # General behavior and transport
  config.enabled = env_boolean.call("CHRONOS_ENABLED", true)
  config.error_notifications = env_boolean.call("CHRONOS_ERROR_NOTIFICATIONS", true)
  config.ssl_verify = env_boolean.call("CHRONOS_SSL_VERIFY", true)
  config.timeout = ENV.fetch("CHRONOS_TIMEOUT", "5").to_f
  config.open_timeout = ENV.fetch("CHRONOS_OPEN_TIMEOUT", "2").to_f
  config.queue_size = ENV.fetch("CHRONOS_QUEUE_SIZE", "100").to_i
  config.workers = ENV.fetch("CHRONOS_WORKERS", "1").to_i
  config.sampling_rate = ENV.fetch("CHRONOS_SAMPLING_RATE", "1.0").to_f
  config.ignored_environments = ENV.fetch("CHRONOS_IGNORED_ENVIRONMENTS", "")
                                   .split(",").map(&:strip).reject(&:empty?)

  # Rails integration and privacy
  config.root_directory = Rails.root.to_s
  config.rails_enabled = env_boolean.call("CHRONOS_RAILS_ENABLED", true)
  config.rails_capture_in_console = env_boolean.call("CHRONOS_RAILS_CAPTURE_IN_CONSOLE", false)
  config.rails_capture_in_test = env_boolean.call("CHRONOS_RAILS_CAPTURE_IN_TEST", false)
  config.anonymize_ip = env_boolean.call("CHRONOS_ANONYMIZE_IP", true)

  # Application performance monitoring
  config.apm_enabled = env_boolean.call("CHRONOS_APM_ENABLED", true)
  config.apm_slow_query_threshold_ms = ENV.fetch(
    "CHRONOS_APM_SLOW_QUERY_THRESHOLD_MS", "500"
  ).to_f
  config.apm_long_transaction_threshold_ms = ENV.fetch(
    "CHRONOS_APM_LONG_TRANSACTION_THRESHOLD_MS", "1000"
  ).to_f
  config.apm_n_plus_one_threshold = ENV.fetch("CHRONOS_APM_N_PLUS_ONE_THRESHOLD", "5").to_i
  config.external_http_enabled = env_boolean.call("CHRONOS_EXTERNAL_HTTP_ENABLED", false)

  # Chronos keeps the shared Rails logger mutable and contains logger failures.
  begin
    config.logger = Rails.logger if Rails.respond_to?(:logger)
  rescue StandardError
    # Chronos safely continues without an application logger.
  end
end

# Installation is idempotent, regardless of when the Railtie was evaluated.
Chronos::Rails::Installer.new.install(Rails.application)
