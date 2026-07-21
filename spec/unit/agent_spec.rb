RSpec.describe Chronos::Agent do
  it "captures asynchronously and exposes bounded queue diagnostics" do
    transport = FakeTransport.new
    agent = described_class.new(snapshot, :transport => transport)

    expect(agent.notify(RuntimeError.new("failed"))).to eq(true)
    expect(agent.flush(1.0)).to eq(true)
    expect(transport.events.size).to eq(1)
    expect(agent.diagnostics[:queue][:accepted]).to eq(1)
    expect(agent.diagnostics[:accepted]).to eq(1)
    expect(agent.diagnostics[:states][:sent]).to eq(1)
    agent.close(1.0)
  end

  it "does not create workers before the first notification" do
    queue = Chronos::Internal::BoundedQueue.new(1)
    pool = Chronos::Internal::WorkerPool.new(queue, FakeTransport.new, 1)

    described_class.new(snapshot, :queue => queue, :worker_pool => pool, :transport => FakeTransport.new)

    expect(pool.started?).to eq(false)
    pool.close(0.1)
  end

  it "inherits scoped context and bounded breadcrumbs for manual notifications" do
    transport = FakeTransport.new
    agent = described_class.new(snapshot(:breadcrumb_capacity => 1), :transport => transport)

    agent.with_context(:context => {"request_id" => "request-1"}, :user => {"id" => "user-1"}) do
      agent.add_breadcrumb(:category => "custom", :message => "discarded")
      agent.add_breadcrumb(:category => "job", :message => "retained")
      agent.notify_sync(RuntimeError.new("failed"))
    end

    payload = JSON.parse(transport.events.first.body)
    expect(payload["context"]["request_id"]).to eq("request-1")
    expect(payload["context"]["breadcrumbs"].map { |item| item["message"] }).to eq(["retained"])
    expect(payload["payload"]["user"]).to eq("id" => "user-1")
    agent.close(1.0)
  end

  it "deduplicates the same exception across Rails and Rack capture hooks" do
    transport = FakeTransport.new
    agent = described_class.new(snapshot, :transport => transport)
    error = RuntimeError.new("controller failed")

    agent.with_context do
      expect(agent.notify_once(error)).to eq(true)
      expect(agent.notify_once(RuntimeError.new("controller failed"))).to eq(false)
    end
    expect(agent.flush(1.0)).to eq(true)
    expect(transport.events.size).to eq(1)
    agent.close(1.0)
  end

  it "registers bounded runtime ignore rules" do
    transport = FakeTransport.new
    agent = described_class.new(snapshot(:max_ignore_rules => 1), :transport => transport)

    expect(agent.ignore_if { |notice| notice.message == "expected" }).to eq(true)
    expect(agent.ignore_if { |_notice| true }).to eq(false)
    expect(agent.notify_sync(RuntimeError.new("expected"))).to eq(false)
    expect(transport.events).to be_empty
    agent.close(1.0)
  end

  it "exposes only trace and request identifiers for process propagation" do
    agent = described_class.new(snapshot, :transport => FakeTransport.new)

    context = agent.with_context(
      :context => {"trace_id" => "trace-1", "secret" => "excluded",
                   "request" => {"request_id" => "request-1", "path" => "/private"}}
    ) { agent.propagation_context }

    expect(context).to eq("trace_id" => "trace-1", "request_id" => "request-1")
    agent.close(1.0)
  end

  it "deduplicates one request metric across nested Rails and Rack hooks" do
    transport = FakeTransport.new
    agent = described_class.new(snapshot, :transport => transport)

    agent.with_context do
      expect(agent.record_event_once("request", "request", "route" => "/users", "duration_ms" => 10)).to eq(true)
      expect(agent.record_event_once("request", "request", "route" => "/users", "duration_ms" => 10)).to eq(false)
    end
    agent.flush(1.0)
    payload = JSON.parse(transport.events.first.body)
    expect(payload["payload"]["metrics"].first["count"]).to eq(1)
    agent.close(1.0)
  end
end
