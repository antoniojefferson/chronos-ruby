RSpec.describe "Bounded diagnostic context" do
  it "sanitizes sensitive symbols in the final exception and telemetry envelopes" do
    values = {"note" => :"Bearer synthetic-private-token", "contact" => :"synthetic@example.com"}
    notice = Chronos::Core::NoticeBuilder.new(snapshot).call(RuntimeError.new("synthetic"), :parameters => values)
    event = Chronos::Core::TelemetryEvent.new("request", values)
    bodies = [Chronos::Core::PayloadSerializer.new(snapshot).call(notice).body,
              Chronos::Core::TelemetrySerializer.new(snapshot).call(event).body]
    bodies.each do |body|
      expect(body).not_to include("synthetic-private-token", "synthetic@example.com")
      expect(body).to include("FILTERED")
    end
  end

  it "bounds cyclic and deeply nested structures before constructing immutable events" do
    cyclic = {}
    cyclic["self"] = cyclic
    array = []
    array << array
    nested = "leaf"
    5000.times { nested = {"nested" => nested} }
    [cyclic, array, nested].each do |value|
      notice = Chronos::Core::NoticeBuilder.new(snapshot).call(RuntimeError.new("synthetic"), :parameters => value)
      event = Chronos::Core::TelemetryEvent.new("request", "context" => value)
      expect { Chronos::Core::PayloadSerializer.new(snapshot).call(notice) }.not_to raise_error
      expect { Chronos::Core::TelemetrySerializer.new(snapshot).call(event) }.not_to raise_error
    end
  end

  it "does not freeze or retain mutable caller-owned telemetry objects" do
    payload = {"nested" => ["original"]}
    event_type = "request"
    event_id = "custom-event-id"
    event = Chronos::Core::TelemetryEvent.new(event_type, payload, {}, :event_id => event_id)
    payload["nested"] << "changed"
    payload["nested"][0].replace("updated")

    expect(event.payload["nested"]).to eq(["original"])
    expect(event.payload["nested"]).to be_frozen
    expect(payload).not_to be_frozen
    expect(event_type).not_to be_frozen
    expect(event_id).not_to be_frozen
  end

  it "contains recursive context in the public facade including overlapping scoped context" do
    cyclic = {}
    cyclic["self"] = cyclic
    transport = FakeTransport.new
    agent = Chronos::Agent.new(snapshot, :transport => transport)
    allow(Chronos).to receive(:current_agent).and_return(agent)
    begin
      Chronos.with_context(:parameters => cyclic) do
        expect(Chronos.notify(RuntimeError.new("synthetic"), :parameters => cyclic)).to eq(true)
        expect(Chronos.record_event("request", "custom" => cyclic)).to eq(true)
      end
      expect(agent.flush(1)).to eq(true)
      expect(transport.events).not_to be_empty
    ensure
      agent.close(1) if agent
    end
  end

  it "bounds collection traversal and discards oversized strings instead of leaking truncated secrets" do
    value = {"items" => (1..10_000).to_a, "oversized" => "private_marker#{'a' * 10_000}"}
    copied = Chronos::Core::BoundedCopy.new.call(value)
    expect(copied["items"].length).to eq(100)
    expect(copied["oversized"]).to eq("<string limit reached>")
  end
end
