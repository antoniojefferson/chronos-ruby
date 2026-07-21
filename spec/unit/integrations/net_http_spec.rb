require "chronos/net_http"

RSpec.describe Chronos::Integrations::NetHttp do # rubocop:disable Metrics/BlockLength
  class ExternalHttpNotifier
    attr_reader :events

    def initialize
      @events = []
    end

    def propagation_context
      {"trace_id" => "trace-1", "request_id" => "request-1"}
    end

    def record_event(type, payload, context = {})
      @events << [type, payload, context]
      true
    end
  end

  class ExternalHttpRequest
    attr_reader :method, :path, :body

    def initialize
      @method = "POST"
      @path = "/customers/42?token=secret"
      @body = "private-body"
      @headers = {"Authorization" => "Bearer private"}
    end

    def [](name)
      @headers[name]
    end

    def []=(name, value)
      @headers[name] = value
    end
  end

  class ExternalHttpResponse
    attr_reader :code

    def initialize(code)
      @code = code.to_s
    end
  end

  class ExternalHttpConnection
    attr_reader :address, :calls

    def initialize(result)
      @address = "API.Example.Test"
      @result = result
      @calls = 0
    end

    def request(_request, _body = nil)
      @calls += 1
      raise @result if @result.is_a?(Exception)

      @result
    end
  end

  it "instruments one connection without collecting URL, authorization, or body" do
    notifier = ExternalHttpNotifier.new
    connection = ExternalHttpConnection.new(ExternalHttpResponse.new(201))
    request = ExternalHttpRequest.new
    ticks = [1.0, 1.025]

    expect(described_class.install(connection, :notifier => notifier, :clock => proc { ticks.shift })).to eq(true)
    expect(described_class.install(connection, :notifier => notifier)).to eq(false)
    expect(connection.request(request).code).to eq("201")

    event = notifier.events.first
    expect(event[0]).to eq("external_http")
    expect(event[1]).to include(
      "host" => "api.example.test", "method" => "POST", "status" => 201,
      "duration_ms" => 25.0, "timeout" => false
    )
    expect(request["X-Chronos-Trace-ID"]).to eq("trace-1")
    expect(request["X-Chronos-Request-ID"]).to eq("request-1")
    expect(event.to_s).not_to include("customers", "Authorization", "private", "secret")
  end

  it "records a bounded timeout class and re-raises the same failure" do
    notifier = ExternalHttpNotifier.new
    error = Net::ReadTimeout.new("private timeout details")
    connection = ExternalHttpConnection.new(error)
    ticks = [2.0, 2.01]
    described_class.install(connection, :notifier => notifier, :clock => proc { ticks.shift })

    expect { connection.request(ExternalHttpRequest.new) }.to(
      raise_error { |raised| expect(raised).to equal(error) }
    )
    expect(notifier.events.first[1]).to include(
      "timeout" => true, "error_class" => "Net::ReadTimeout", "duration_ms" => 10.0
    )
    expect(notifier.events.first.to_s).not_to include("private timeout details")
  end

  it "classifies a connection failure without collecting its message" do
    notifier = ExternalHttpNotifier.new
    connection = ExternalHttpConnection.new(SocketError.new("private host details"))
    ticks = [3.0, 3.01]
    described_class.install(connection, :notifier => notifier, :clock => proc { ticks.shift })

    expect { connection.request(ExternalHttpRequest.new) }.to raise_error(SocketError)
    expect(notifier.events.first[1]).to include(
      "connection_error" => true, "timeout" => false, "error_class" => "SocketError"
    )
    expect(notifier.events.first.to_s).not_to include("private host details")
  end
end
