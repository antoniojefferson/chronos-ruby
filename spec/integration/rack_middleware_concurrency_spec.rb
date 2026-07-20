RSpec.describe Chronos::Integrations::Rack::Middleware, "concurrency" do
  def rack_env(identifier)
    {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/accounts/42",
      "HTTP_HOST" => "example.test",
      "HTTP_X_REQUEST_ID" => "request-#{identifier}",
      "chronos.trace_id" => "trace-#{identifier}",
      "chronos.user" => {"id" => "user-#{identifier}"},
      "rack.request.query_hash" => {"owner" => identifier}
    }
  end

  it "isolates user, parameters, breadcrumbs, and trace IDs across concurrent requests" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(snapshot, :transport => transport)
    ready = Queue.new
    release = Queue.new
    app = proc do |_env|
      ready << true
      release.pop
      raise "concurrent failure"
    end
    middleware = described_class.new(app, :notifier => agent)

    threads = %w(one two).map do |identifier|
      Thread.new do
        begin
          middleware.call(rack_env(identifier))
        rescue RuntimeError
          nil
        end
      end
    end
    2.times { ready.pop }
    2.times { release << true }
    threads.each(&:join)
    expect(agent.flush(1.0)).to eq(true)

    contexts = transport.events.map do |event|
      payload = JSON.parse(event.body)
      [payload["context"]["trace_id"], payload["payload"]["user"]["id"],
       payload["payload"]["parameters"]["owner"], payload["context"]["breadcrumbs"].size]
    end.sort
    expected = [
      ["trace-one", "user-one", "one", 1],
      ["trace-two", "user-two", "two", 1]
    ]
    expect(contexts).to eq(expected)
    agent.close(1.0)
  end
end
