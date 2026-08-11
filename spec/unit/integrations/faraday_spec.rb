require "uri"

RSpec.describe Chronos::Integrations::FaradayMiddleware do
  class FakeFaradayEnvironment
    attr_reader :request_headers, :url, :status

    def initialize
      @request_headers = {}
      @url = URI("https://api.example.test/private?token=x")
      @status = 200
    end

    def method
      :get
    end
  end

  it "propagates W3C context and records bounded request metadata" do
    notifier = double("notifier")
    allow(notifier).to receive(:external_http_integration_options).and_return(
      :trace_headers => true, :w3c_trace_context => true
    )
    allow(notifier).to receive(:propagation_context).and_return(
      "trace_id" => "a" * 32, "span_id" => "b" * 16, "trace_flags" => "01"
    )
    expect(notifier).to receive(:record_event).with(
      "external_http", include("host" => "api.example.test", "method" => "GET", "status" => 200)
    )
    environment = FakeFaradayEnvironment.new
    ticks = [1.0, 1.01]
    middleware = described_class.new(proc { |value| value }, :notifier => notifier, :clock => proc { ticks.shift })

    expect(middleware.call(environment)).to equal(environment)
    expect(environment.request_headers["traceparent"]).to eq("00-#{'a' * 32}-#{'b' * 16}-01")
  end
end
