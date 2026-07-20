require "chronos/rails"

Chronos.configure do |config|
  # Chronos reads only the environment variables explicitly selected here.
  config.project_id = ENV["CHRONOS_PROJECT_ID"]
  config.project_key = ENV["CHRONOS_PROJECT_KEY"]
  config.host = ENV["CHRONOS_HOST"]
  config.environment = Rails.env.to_s
  config.service_name = ENV["CHRONOS_SERVICE_NAME"]
  config.app_version = ENV["CHRONOS_APP_VERSION"]
  config.logger = Rails.logger if Rails.respond_to?(:logger)

  # Safe legacy defaults: test and console integrations remain disabled.
  config.rails_capture_in_test = false
  config.rails_capture_in_console = false
  config.rails_capture_user_agent = false
end

# Safe when the Railtie already ran or will run later; installation is idempotent.
Chronos::Rails::Installer.new.install(Rails.application)
