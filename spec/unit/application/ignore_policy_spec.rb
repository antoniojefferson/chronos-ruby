RSpec.describe Chronos::Application::IgnorePolicy do
  it "bounds runtime rules and contains rule failures" do
    warnings = []
    logger = Object.new
    logger.define_singleton_method(:warn) { |message| warnings << message }
    policy = described_class.new([proc { |_notice| raise "failed" }], 2, logger)
    notice = Struct.new(:exception_class).new("ExpectedError")

    expect(policy.add { |candidate| candidate.exception_class == "ExpectedError" }).to eq(true)
    expect(policy.add { true }).to eq(false)
    expect(policy.ignored?(notice)).to eq(true)
    expect(warnings.first).to include("RuntimeError")
  end
end
