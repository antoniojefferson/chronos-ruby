RSpec.describe "Rails legacy integration contract" do
  it "ships an explicit initializer template with safe defaults" do
    path = File.expand_path("../../lib/generators/chronos/install/templates/chronos.rb", __dir__)
    template = File.read(path)

    expect(template).to include(
      "require \"chronos/rails\"", "CHRONOS_PROJECT_ID", "CHRONOS_PROJECT_KEY", "CHRONOS_HOST",
      "config.rails_capture_in_test = false", "config.rails_capture_in_console = false",
      "Chronos::Rails::Installer.new.install(Rails.application)"
    )
    expect(template).not_to include("ENV.to_h", "ENV.each")
  end

  it "loads the Rails integration without requiring Zeitwerk" do
    require "chronos/rails"

    expect(defined?(Chronos::Rails::Installer)).to eq("constant")
    expect(defined?(Chronos::Rails::NotificationsSubscriber)).to eq("constant")
    expect($LOADED_FEATURES.grep(/zeitwerk/)).to be_empty
  end
end
