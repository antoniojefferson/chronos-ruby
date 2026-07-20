Chronos.configure do |config|
  config.project_id = ENV["CHRONOS_PROJECT_ID"] || "rails-4-2-example"
  config.project_key = ENV["CHRONOS_PROJECT_KEY"] || "development-only"
  config.host = ENV["CHRONOS_HOST"] || "http://127.0.0.1:1"
  config.environment = Rails.env.to_s
  config.service_name = "rails-4-2-example"
  config.logger = Rails.logger
  config.ssl_verify = false
  config.open_timeout = 0.05
  config.timeout = 0.05
  config.max_retries = 0
end

at_exit { Chronos.close(1.0) }
