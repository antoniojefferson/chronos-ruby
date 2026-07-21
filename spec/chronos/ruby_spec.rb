RSpec.describe Chronos do
  it "has a version number" do
    expect(Chronos::VERSION).to eq("0.7.0.pre.1")
  end

  it "defines a base error" do
    expect(Chronos::Error).to be < StandardError
  end

  it "returns false before configuration" do
    expect(Chronos.notify(RuntimeError.new("failed"))).to eq(false)
    expect(Chronos.add_breadcrumb(:message => "ignored")).to eq(false)
    expect(Chronos.with_context(:request_id => "request") { :result }).to eq(:result)
  end
end
