RSpec.describe Chronos::Application::CaptureTelemetry do
  it "queues a supported non-exception event through the delivery pipeline" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(snapshot, :transport => transport)

    expect(agent.record_event("query", "name" => "User Load", "duration_ms" => 2.5)).to eq(true)
    expect(agent.flush(1.0)).to eq(true)

    payload = JSON.parse(transport.events.first.body)
    expect(payload["event_type"]).to eq("query")
    expect(payload["payload"]).to include("name" => "User Load", "duration_ms" => 2.5)
    agent.close(1.0)
  end

  it "contains unsupported event types" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(snapshot, :transport => transport)

    expect(agent.record_event("deploy", "revision" => "abc")).to eq(false)
    expect(transport.events).to be_empty
    agent.close(1.0)
  end
end
