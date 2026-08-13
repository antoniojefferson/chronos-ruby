require "chronos/rails"

RSpec.describe Chronos::Rails do
  describe ".application_name" do
    it "derives the service name from the Rails application namespace" do
      application_class = Class.new
      stub_const("ExampleSystem::Application", application_class)

      expect(described_class.application_name(application_class.new)).to eq("ExampleSystem")
    end

    it "returns nil when the application class is anonymous" do
      expect(described_class.application_name(Class.new.new)).to be_nil
    end

    it "does not let application introspection failures break Rails boot" do
      application = Object.new
      allow(application).to receive(:class).and_raise("not initialized")

      expect(described_class.application_name(application)).to be_nil
    end
  end
end
