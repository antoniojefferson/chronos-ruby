RSpec.describe Chronos::Integrations::Rack::Middleware do
  def rack_env(overrides = {})
    {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/accounts/42",
      "QUERY_STRING" => "password=raw-query-must-not-be-copied",
      "HTTP_HOST" => "example.test",
      "HTTP_X_REQUEST_ID" => "request-1",
      "HTTP_USER_AGENT" => "test-browser",
      "rack.input" => Object.new,
      "rack.request.query_hash" => {"token" => "secret", "page" => "2"},
      "chronos.user" => {"id" => "user-1"}
    }.merge(overrides)
  end

  it "captures request context, sanitizes parameters, and re-raises the original exception" do
    transport = FakeTransport.new
    store = Chronos::Adapters::ThreadLocalContextStore.new
    agent = Chronos::Agent.new(snapshot, :transport => transport, :context_store => store)
    error = RuntimeError.new("rack failed")
    app = proc { |_env| raise error }
    middleware = described_class.new(app, :notifier => agent, :include_user_agent => true)

    raised = begin
      middleware.call(rack_env)
      nil
    rescue RuntimeError => caught
      caught
    end
    expect(raised).to equal(error)
    expect(agent.flush(1.0)).to eq(true)

    payload = JSON.parse(transport.events.first.body)
    request = payload["context"]["request"]
    expect(request).to include(
      "method" => "GET", "route" => "/accounts/:id", "status" => 500,
      "request_id" => "request-1", "host" => "example.test", "path" => "/accounts/42",
      "user_agent" => "test-browser"
    )
    expect(payload["payload"]["parameters"]).to include("token" => "[FILTERED]", "page" => "2")
    expect(payload["payload"]["user"]).to eq("id" => "user-1")
    expect(payload["context"]["breadcrumbs"].first["category"]).to eq("request")
    expect(payload["context"]["trace_id"]).not_to be_empty
    expect(payload.to_s).not_to include("raw-query-must-not-be-copied")
    expect(store.get).to eq({})
    agent.close(1.0)
  end

  it "does not read the request body or enumerate a successful response body" do
    input = Object.new
    body = Object.new
    def input.read
      raise "request body was consumed"
    end

    def body.each
      raise "response body was consumed"
    end
    agent = Chronos::Agent.new(snapshot, :transport => FakeTransport.new)
    app = proc { |_env| [200, {"Content-Length" => "12"}, body] }
    middleware = described_class.new(app, :notifier => agent)

    expect(middleware.call(rack_env("rack.input" => input))).to eq([200, {"Content-Length" => "12"}, body])
    agent.close(1.0)
  end

  it "preserves the application exception when notification itself fails" do
    notifier = Object.new
    def notifier.with_context(_context)
      yield
    end

    def notifier.add_breadcrumb(_attributes)
      true
    end

    def notifier.notify(_error, _context)
      raise "notification failed"
    end
    original = RuntimeError.new("application failed")
    middleware = described_class.new(proc { |_env| raise original }, :notifier => notifier)

    raised = begin
      middleware.call(rack_env)
      nil
    rescue RuntimeError => caught
      caught
    end
    expect(raised).to equal(original)
  end
end
