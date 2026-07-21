RSpec.describe Chronos::Application::CaptureTelemetry do
  it "queues a supported non-exception event through the delivery pipeline" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(snapshot, :transport => transport)

    expect(agent.record_event("query", "name" => "User Load", "duration_ms" => 2.5)).to eq(true)
    expect(agent.flush(1.0)).to eq(true)

    payload = JSON.parse(transport.events.first.body)
    expect(payload["event_type"]).to eq("metric_batch")
    metric = payload["payload"]["metrics"].first
    expect(metric).to include("metric_type" => "query", "count" => 1)
    expect(metric["dimensions"]).to include("name" => "User Load")
    expect(metric["duration_ms"]["total"]).to eq(2.5)
    agent.close(1.0)
  end

  it "contains unsupported event types" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(snapshot, :transport => transport)

    expect(agent.record_event("unsupported", "revision" => "abc")).to eq(false)
    expect(agent.record_event("deploy", "revision" => "abc")).to eq(false)
    expect(transport.events).to be_empty
    agent.close(1.0)
  end

  it "falls back to individual telemetry when metric batches are locally disabled" do
    transport = FakeTransport.new
    enabled = ["exception", "query"]
    agent = Chronos::Agent.new(snapshot(:enabled_event_types => enabled), :transport => transport)

    expect(agent.record_event("query", "name" => "User Load", "duration_ms" => 2.5)).to eq(true)
    expect(agent.flush(1.0)).to eq(true)
    payload = JSON.parse(transport.events.first.body)
    expect(payload["event_type"]).to eq("query")
    agent.close(1.0)
  end
end
