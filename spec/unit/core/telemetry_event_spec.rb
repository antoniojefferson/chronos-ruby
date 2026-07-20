RSpec.describe Chronos::Core::TelemetrySerializer do
  it "serializes sanitized Rails telemetry into the common envelope" do
    event = Chronos::Core::TelemetryEvent.new(
      "request",
      {"kind" => "controller", "parameters" => {"password" => "secret"}},
      {"framework" => "rails"},
      :event_id => "event-1", :clock => proc { Time.utc(2026, 1, 2, 3, 4, 5) }
    )

    payload = JSON.parse(described_class.new(snapshot).call(event).body)

    expect(payload["event_id"]).to eq("event-1")
    expect(payload["event_type"]).to eq("request")
    expect(payload["context"]).to eq("framework" => "rails")
    expect(payload["payload"]["parameters"]["password"]).to eq("[FILTERED]")
  end

  it "rejects unsupported integration event types" do
    expect { Chronos::Core::TelemetryEvent.new("mailer") }.to raise_error(ArgumentError)
  end
end
