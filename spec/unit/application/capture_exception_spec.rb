RSpec.describe Chronos::Application::CaptureException do
  def build_capture(config, transport)
    pipeline = Chronos::Application::DeliveryPipeline.new(config, transport, nil, :sleeper => proc { |_delay| nil })
    [described_class.new(config, pipeline), pipeline]
  end

  it "delivers a synchronous exception" do
    config = snapshot
    transport = FakeTransport.new
    capture, pipeline = build_capture(config, transport)

    expect(capture.call_sync(RuntimeError.new("failed"))).to eq(true)
    expect(transport.events.size).to eq(1)
    pipeline.close(0.1)
  end

  it "contains invalid input and transport failures" do
    config = snapshot
    transport = RaisingTransport.new
    capture, pipeline = build_capture(config, transport)

    expect { capture.call_sync("not an exception") }.not_to raise_error
    expect(capture.call_sync(RuntimeError.new("failed"))).to eq(false)
    pipeline.close(0.1)
  end

  it "does not capture in an ignored environment" do
    config = snapshot(:environment => "test", :ignored_environments => ["test"])
    transport = FakeTransport.new
    capture, pipeline = build_capture(config, transport)

    expect(capture.call(RuntimeError.new("ignored"))).to eq(false)
    expect(transport.events).to be_empty
    pipeline.close(0.1)
  end

  it "contains failures from the configured logger" do
    logger = Object.new
    def logger.warn(_message)
      raise "logger failed"
    end
    config = snapshot(:logger => logger)
    transport = RaisingTransport.new
    safe_logger = Chronos::Internal::SafeLogger.new(logger)
    pipeline = Chronos::Application::DeliveryPipeline.new(config, transport, safe_logger)
    capture = described_class.new(config, pipeline, safe_logger)

    expect { capture.call_sync(RuntimeError.new("failed")) }.not_to raise_error
    pipeline.close(0.1)
  end

  it "stops later captures when the bounded remote kill switch is active" do
    config = snapshot
    transport = FakeTransport.new
    capture, pipeline = build_capture(config, transport)
    pipeline.remote_configuration.apply("kill_switch" => true)

    expect(capture.call(RuntimeError.new("disabled"))).to eq(false)
    expect(transport.events).to be_empty
    pipeline.close(0.1)
  end
end
