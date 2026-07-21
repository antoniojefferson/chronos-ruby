#!/usr/bin/env ruby

require "chronos"

def required_environment(name)
  value = ENV[name].to_s
  abort "#{name} is required" if value.empty?

  value
end

Chronos.configure do |config|
  config.project_id = required_environment("CHRONOS_PROJECT_ID")
  config.project_key = required_environment("CHRONOS_PROJECT_KEY")
  config.host = required_environment("CHRONOS_HOST")
  config.environment = required_environment("DEPLOY_ENVIRONMENT")
  config.service_name = ENV["SERVICE_NAME"]
  config.app_version = ENV["APP_VERSION"]
  config.revision = ENV["GIT_SHA"]
  config.deploy_id = ENV["DEPLOY_ID"]
  config.region = ENV["DEPLOY_REGION"]
  config.instance_id = ENV["DEPLOY_INSTANCE"]
end

delivered = Chronos.notify_deploy(
  :environment => ENV["DEPLOY_ENVIRONMENT"], :revision => ENV["GIT_SHA"],
  :version => ENV["APP_VERSION"], :repository => ENV["DEPLOY_REPOSITORY"],
  :actor => ENV["DEPLOY_ACTOR"], :deploy_id => ENV["DEPLOY_ID"],
  :service => ENV["SERVICE_NAME"], :region => ENV["DEPLOY_REGION"],
  :instance => ENV["DEPLOY_INSTANCE"]
)
closed = Chronos.close(5.0)
abort "Chronos deploy notification failed" unless delivered && closed

puts "Chronos deploy notification delivered"
