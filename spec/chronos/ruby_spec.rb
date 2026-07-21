RSpec.describe Chronos do
  class PublicHttpConnection
    attr_reader :address

    def initialize
      @address = "api.example.test"
    end

    def request(_request, _body = nil)
      true
    end
  end

  it "has a version number" do
    expect(Chronos::VERSION).to eq("0.9.0.pre.2")
  end

  it "defines a base error" do
    expect(Chronos::Error).to be < StandardError
  end

  it "returns false before configuration" do
    expect(Chronos.notify(RuntimeError.new("failed"))).to eq(false)
    expect(Chronos.add_breadcrumb(:message => "ignored")).to eq(false)
    expect(Chronos.notify_deploy(:revision => "abc123")).to eq(false)
    expect(Chronos.with_context(:request_id => "request") { :result }).to eq(:result)
  end

  it "installs outbound HTTP instrumentation only after explicit enablement" do
    Chronos.configure do |config|
      config.project_id = "project-id"
      config.project_key = "project-key"
      config.host = "https://chronos.example.test"
      config.dependency_reporting = false
      config.external_http_enabled = true
    end

    expect(Chronos.instrument_net_http(PublicHttpConnection.new)).to eq(true)
    expect(Chronos.close(1.0)).to eq(true)
  end
end
