RSpec.describe "Rails legacy integration contract" do
  it "ships an explicit initializer template with safe defaults" do
    path = File.expand_path("../../lib/generators/chronos/install/templates/chronos.rb", __dir__)
    template = File.read(path)

    expect(template).to include(
      "require \"chronos/rails\"", "CHRONOS_PROJECT_ID", "CHRONOS_PROJECT_KEY",
      'config.service_name = ENV["CHRONOS_SERVICE_NAME"] || Chronos::Rails.application_name',
      'config.ssl_verify = env_boolean.call("CHRONOS_SSL_VERIFY", true)',
      'config.environment = ENV.fetch("CHRONOS_ENVIRONMENT", Rails.env.to_s)',
      'config.timeout = ENV.fetch("CHRONOS_TIMEOUT", "5").to_f',
      'config.rails_capture_in_test = env_boolean.call("CHRONOS_RAILS_CAPTURE_IN_TEST", false)',
      'config.rails_capture_in_console = env_boolean.call("CHRONOS_RAILS_CAPTURE_IN_CONSOLE", false)',
      "next true if %w(1 true yes on).include?(normalized)",
      "next false if %w(0 false no off).include?(normalized)",
      "Chronos::Rails::Installer.new.install(Rails.application)"
    )

    expect(template).not_to include("config.host =")
    expect(template).to include("rescue StandardError", "config.logger = Rails.logger")
    expect(template).not_to include("CHRONOS_HOST", "ENV.to_h", "ENV.each", "config.proxy =")
  end

  it "loads the Rails integration without requiring Zeitwerk" do
    require "chronos/rails"

    expect(defined?(Chronos::Rails::Installer)).to eq("constant")
    expect(defined?(Chronos::Rails::NotificationsSubscriber)).to eq("constant")
    expect(defined?(Chronos::Integrations::Sidekiq)).to eq("constant")
    expect($LOADED_FEATURES.grep(/zeitwerk/)).to be_empty
  end
end
