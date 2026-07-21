require "chronos/net_http"

RSpec.describe "external HTTP aggregation" do
  class AggregationHttpResponse
    attr_reader :code

    def initialize(code)
      @code = code.to_s
    end
  end

  class AggregationHttpConnection
    attr_reader :address

    def initialize
      @address = "payments.example.test"
    end

    def request(_request, _body = nil)
      AggregationHttpResponse.new(204)
    end
  end

  class AggregationHttpRequest
    attr_reader :method

    def initialize
      @method = "GET"
      @headers = {}
    end

    def [](name)
      @headers[name]
    end

    def []=(name, value)
      @headers[name] = value
    end
  end

  it "adds external HTTP duration to a bounded metric batch" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(snapshot(:external_http_enabled => true), :transport => transport)
    connection = AggregationHttpConnection.new
    ticks = [1.0, 1.02]
    Chronos::Integrations::NetHttp.install(connection, :notifier => agent, :clock => proc { ticks.shift })

    agent.with_context(:context => {"trace_id" => "trace-1"}) do
      connection.request(AggregationHttpRequest.new)
      agent.record_event(
        "request", "route" => "/payments", "method" => "POST", "status" => 200, "duration_ms" => 50.0
      )
    end
    expect(agent.flush(1.0)).to eq(true)

    batch = JSON.parse(transport.events.first.body)
    metrics = batch["payload"]["metrics"]
    external = metrics.find { |metric| metric["metric_type"] == "external_http" }
    request = metrics.find { |metric| metric["metric_type"] == "request" }
    expect(external["dimensions"]).to include("host" => "payments.example.test", "method" => "GET")
    expect(external["status_codes"]).to eq("204" => 1)
    expect(request["breakdown_ms"]["external_http"]).to eq(20.0)
    agent.close(1.0)
  end
end
