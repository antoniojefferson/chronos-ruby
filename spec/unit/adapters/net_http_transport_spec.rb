RSpec.describe Chronos::Adapters::NetHttpTransport do
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

  it "sends authentication and idempotency headers on success" do
    server = FakeHttpServer.new("202 Accepted")
    result = transport_for(server).send_event(event)
    server.stop

    expect(result).to be_success
    expect(server.request_line).to start_with("POST /api/v1/events")
    expect(server.request_headers["x-chronos-project-key"]).to eq("project-key")
    expect(server.request_headers["idempotency-key"]).to eq("event-id")
    expect(server.request_body).not_to include("project-key")
  end

  it "classifies rate limiting and Retry-After" do
    server = FakeHttpServer.new("429 Too Many Requests", :headers => {"Retry-After" => "10"})
    result = transport_for(server).send_event(event)
    server.stop

    expect(result.status).to eq(:rate_limited)
    expect(result.retry_after).to eq("10")
    expect(result).to be_retryable
  end

  it "optionally compresses the request body with gzip" do
    server = FakeHttpServer.new("202 Accepted")
    result = transport_for(server, :gzip => true).send_event(event)
    server.stop
    reader = Zlib::GzipReader.new(StringIO.new(server.request_body))

    expect(result).to be_success
    expect(server.request_headers["content-encoding"]).to eq("gzip")
    expect(reader.read).to eq(event.body)
    reader.close
  end

  it "classifies server errors as retryable" do
    server = FakeHttpServer.new("500 Internal Server Error")
    result = transport_for(server).send_event(event)
    server.stop

    expect(result.status).to eq(:server_error)
    expect(result).to be_retryable
  end

  it "classifies permanent client errors without retry" do
    server = FakeHttpServer.new("400 Bad Request")
    result = transport_for(server).send_event(event)
    server.stop

    expect(result.status).to eq(:client_error)
    expect(result).not_to be_retryable
  end

  it "contains read timeouts" do
    server = FakeHttpServer.new("202 Accepted", :delay => 0.2)
    result = transport_for(server, :timeout => 0.05).send_event(event)
    server.stop

    expect(result.status).to eq(:network_error)
    expect(result).to be_retryable
  end

  it "contains invalid TLS responses" do
    server = FakeHttpServer.new("202 Accepted")
    config = snapshot(:host => server.url("https"), :ssl_verify => true, :timeout => 0.1, :open_timeout => 0.1)
    result = described_class.new(config).send_event(event)
    server.stop

    expect(result.status).to eq(:network_error)
  end
end
