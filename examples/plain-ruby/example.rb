require "chronos"

Chronos.configure do |config|
  config.project_id = ENV.fetch("CHRONOS_PROJECT_ID")
  config.project_key = ENV.fetch("CHRONOS_PROJECT_KEY")
  config.host = ENV.fetch("CHRONOS_HOST")
  config.environment = ENV["APP_ENV"] || "development"
  config.service_name = "plain-ruby-example"
end

begin
  raise "example failure"
rescue StandardError => error
  Chronos.notify(error, :context => {"operation" => "example"})
ensure
  Chronos.close(2.0)
end
