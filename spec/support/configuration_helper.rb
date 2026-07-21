module ConfigurationHelper
  def configuration(overrides = {})
    config = Chronos::Configuration.new
    config.project_id = "project-id"
    config.project_key = "project-key"
    config.host = "https://chronos.example.test"
    config.dependency_reporting = false
    overrides.each { |key, value| config.public_send("#{key}=", value) }
    config
  end

  def snapshot(overrides = {})
    configuration(overrides).snapshot
  end
end

RSpec.configure do |config|
  config.include ConfigurationHelper
end
