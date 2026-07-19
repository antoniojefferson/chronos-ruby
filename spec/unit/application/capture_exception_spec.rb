RSpec.describe Chronos::Application::CaptureException do
  def build_capture(config, transport)
    queue = Chronos::Internal::BoundedQueue.new(config.queue_size)
    pool = Chronos::Internal::WorkerPool.new(queue, transport, config.workers)
    [described_class.new(config, pool, transport), pool]
  end

  it "delivers a synchronous exception" do
    config = snapshot
    transport = FakeTransport.new
    capture, pool = build_capture(config, transport)

    expect(capture.call_sync(RuntimeError.new("failed"))).to eq(true)
    expect(transport.events.size).to eq(1)
    pool.close(0.1)
  end

  it "contains invalid input and transport failures" do
    config = snapshot
    transport = RaisingTransport.new
    capture, pool = build_capture(config, transport)

    expect { capture.call_sync("not an exception") }.not_to raise_error
    expect(capture.call_sync(RuntimeError.new("failed"))).to eq(false)
    pool.close(0.1)
  end

  it "does not capture in an ignored environment" do
    config = snapshot(:environment => "test", :ignored_environments => ["test"])
    transport = FakeTransport.new
    capture, pool = build_capture(config, transport)

    expect(capture.call(RuntimeError.new("ignored"))).to eq(false)
    expect(transport.events).to be_empty
    pool.close(0.1)
  end

  it "contains failures from the configured logger" do
    logger = Object.new
    def logger.warn(_message)
      raise "logger failed"
    end
    config = snapshot(:logger => logger)
    transport = RaisingTransport.new
    queue = Chronos::Internal::BoundedQueue.new(1)
    safe_logger = Chronos::Internal::SafeLogger.new(logger)
    pool = Chronos::Internal::WorkerPool.new(queue, transport, 1, safe_logger)
    capture = described_class.new(config, pool, transport, safe_logger)

    expect { capture.call_sync(RuntimeError.new("failed")) }.not_to raise_error
    pool.close(0.1)
  end
end
