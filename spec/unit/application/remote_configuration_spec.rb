RSpec.describe Chronos::Application::RemoteConfiguration do
  it "applies only bounded allowlisted scalar settings" do
    remote = described_class.new(snapshot)

    applied = remote.apply(
      "sampling_rate" => 0.25,
      "enabled_event_types" => ["exception", "query"],
      "max_payload_size" => 2048,
      "ignored_fingerprints" => ["expected-error"],
      "send_interval" => 2.0,
      "kill_switch" => true,
      "host" => "https://attacker.example",
      "project_key" => "stolen",
      "code" => "Kernel.exit!"
    )

    expect(applied).to eq(true)
    expect(remote.sampling_rate).to eq(0.25)
    expect(remote.enabled_event?("exception")).to eq(true)
    expect(remote.enabled_event?("query")).to eq(true)
    expect(remote.max_payload_size).to eq(2048)
    expect(remote.ignored_fingerprint?("expected-error")).to eq(true)
    expect(remote.send_interval).to eq(2.0)
    expect(remote.kill_switch?).to eq(true)
    expect(remote.to_h).not_to have_key("host")
    expect(remote.to_h).not_to have_key("project_key")
    expect(remote.to_h).not_to have_key("code")
  end

  it "rejects invalid, oversized, and regex-shaped values without changing state" do
    remote = described_class.new(snapshot)

    expect(remote.apply("sampling_rate" => 2.0, "ignored_fingerprints" => [/.*/])).to eq(false)
    expect(remote.sampling_rate).to eq(1.0)
    expect(remote.ignored_fingerprints).to eq([])
  end

  it "never enables an event type disabled by local configuration" do
    remote = described_class.new(snapshot(:enabled_event_types => []))

    expect(remote.apply("enabled_event_types" => ["exception"])).to eq(true)
    expect(remote.enabled_event?("exception")).to eq(false)
  end
end
