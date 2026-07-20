RSpec.describe Chronos::Application::DeliveryPipeline do
  def event(id)
    Chronos::Core::SerializedEvent.new(id, "{\"safe\":true}")
  end

  def result(status, options = {})
    Chronos::Ports::TransportResult.new(status, options)
  end

  it "records explicit delivery states and retries retryable failures" do
    delays = []
    transport = FakeTransport.new([result(:server_error), result(:success, :status_code => 202)])
    pipeline = described_class.new(
      snapshot(:retry_base_interval => 0.01),
      transport,
      nil,
      :sleeper => proc { |delay| delays << delay }
    )

    expect(pipeline.deliver_sync(event("one"))).to eq(true)
    expect(pipeline.diagnostics[:states]).to include(
      :accepted => 1,
      :serialized => 1,
      :retried => 1,
      :sent => 1
    )
    expect(delays.size).to eq(1)
    pipeline.close(0.1)
  end

  it "does not retry permanent 4xx responses and marks them rejected" do
    transport = FakeTransport.new([result(:client_error, :status_code => 400)])
    pipeline = described_class.new(snapshot, transport)

    expect(pipeline.deliver_sync(event("one"))).to eq(false)
    expect(transport.events.size).to eq(1)
    expect(pipeline.diagnostics[:states][:rejected]).to eq(1)
    pipeline.close(0.1)
  end

  it "moves failures into a bounded backlog and drains it after recovery" do
    now = 0.0
    transport = FakeTransport.new(
      [
        result(:network_error), result(:network_error),
        result(:success, :status_code => 202), result(:success, :status_code => 202)
      ]
    )
    config = snapshot(
      :max_retries => 1,
      :retry_base_interval => 0.01,
      :circuit_failure_threshold => 2,
      :circuit_reset_timeout => 1.0,
      :backlog_size => 2
    )
    pipeline = described_class.new(config, transport, nil, :clock => proc { now }, :sleeper => proc { |_delay| nil })

    expect(pipeline.deliver_sync(event("one"))).to eq(false)
    expect(pipeline.diagnostics[:backlog][:size]).to eq(1)

    now = 1.0
    expect(pipeline.deliver_sync(event("two"))).to eq(true)
    expect(pipeline.diagnostics[:backlog][:size]).to eq(0)
    expect(pipeline.diagnostics[:states][:sent]).to eq(2)
    pipeline.close(0.1)
  end

  it "bounds memory while the endpoint remains unavailable" do
    transport = FakeTransport.new(Array.new(20) { result(:network_error) })
    config = snapshot(:max_retries => 0, :circuit_failure_threshold => 1, :backlog_size => 2)
    pipeline = described_class.new(config, transport)

    10.times { |index| pipeline.deliver_sync(event(index.to_s)) }

    expect(pipeline.diagnostics[:backlog][:size]).to eq(2)
    expect(pipeline.diagnostics[:backlog][:dropped]).to eq(8)
    expect(pipeline.diagnostics[:states][:dropped]).to eq(8)
    pipeline.close(0.1)
  end

  it "applies safe remote configuration returned by the transport" do
    remote_values = {"kill_switch" => true, "host" => "https://attacker.example"}
    transport = FakeTransport.new([result(:success, :remote_configuration => remote_values)])
    pipeline = described_class.new(snapshot, transport)

    expect(pipeline.deliver_sync(event("one"))).to eq(true)
    expect(pipeline.remote_configuration.kill_switch?).to eq(true)
    expect(pipeline.remote_configuration.to_h).not_to have_key("host")
    pipeline.close(0.1)
  end
end
