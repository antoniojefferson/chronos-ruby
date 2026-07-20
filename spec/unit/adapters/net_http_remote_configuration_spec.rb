RSpec.describe Chronos::Adapters::NetHttpTransport, "remote configuration" do
  def event
    Chronos::Core::SerializedEvent.new("event-id", "{\"message\":\"safe\"}")
  end

  def transport_for(server, overrides = {})
    config = snapshot({
      :host => server.url,
      :ssl_verify => false,
      :timeout => 0.2,
      :open_timeout => 0.2
    }.merge(overrides))
    described_class.new(config)
  end

  it "accepts a bounded JSON object response header" do
    value = JSON.generate("sampling_rate" => 0.5, "kill_switch" => false)
    server = FakeHttpServer.new("202 Accepted", :headers => {"X-Chronos-Remote-Configuration" => value})
    result = transport_for(server).send_event(event)
    server.stop

    expect(result.remote_configuration).to eq("sampling_rate" => 0.5, "kill_switch" => false)
  end

  it "ignores an oversized response header before JSON parsing" do
    value = JSON.generate("ignored_fingerprints" => ["x" * 100])
    server = FakeHttpServer.new("202 Accepted", :headers => {"X-Chronos-Remote-Configuration" => value})
    result = transport_for(server, :remote_config_max_bytes => 32).send_event(event)
    server.stop

    expect(result.remote_configuration).to be_nil
  end
end
