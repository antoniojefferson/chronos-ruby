require "English"

RSpec.describe Chronos::Internal::WorkerPool do
  def event(id)
    Chronos::Core::SerializedEvent.new(id, "{}")
  end

  it "starts lazily and flushes accepted events" do
    queue = Chronos::Internal::BoundedQueue.new(2)
    transport = FakeTransport.new
    pool = described_class.new(queue, transport, 1)

    expect(pool.started?).to eq(false)
    expect(pool.enqueue(event("one"))).to eq(true)
    expect(pool.flush(1.0)).to eq(true)
    expect(transport.events.map(&:event_id)).to eq(["one"])
    pool.close(1.0)
  end

  it "contains transport exceptions and continues draining" do
    queue = Chronos::Internal::BoundedQueue.new(2)
    pool = described_class.new(queue, RaisingTransport.new, 1)

    pool.enqueue(event("one"))

    expect(pool.flush(1.0)).to eq(true)
    expect(pool.close(1.0)).to eq(true)
  end

  it "can be closed twice" do
    pool = described_class.new(Chronos::Internal::BoundedQueue.new(1), FakeTransport.new, 1)

    expect(pool.close(0.1)).to eq(true)
    expect(pool.close(0.1)).to eq(true)
  end

  it "returns false when shutdown cannot finish inside the timeout" do
    transport = FakeTransport.new { sleep(0.3) }
    pool = described_class.new(Chronos::Internal::BoundedQueue.new(1), transport, 1)
    pool.enqueue(event("slow"))

    expect(pool.close(0.02)).to eq(false)
  end

  it "recreates workers after fork" do
    skip "fork is unavailable" unless Process.respond_to?(:fork)

    reader, writer = IO.pipe
    transport = FakeTransport.new do |delivered_event|
      writer.puts(delivered_event.event_id)
      writer.flush
    end
    pool = described_class.new(Chronos::Internal::BoundedQueue.new(2), transport, 1)
    pool.enqueue(event("parent"))
    expect(pool.flush(1.0)).to eq(true)

    child_pid = fork do
      reader.close
      successful = pool.enqueue(event("child")) && pool.flush(1.0)
      pool.close(1.0)
      exit!(successful ? 0 : 1)
    end
    Process.wait(child_pid)
    pool.close(1.0)
    writer.close

    expect($CHILD_STATUS.exitstatus).to eq(0)
    expect(reader.read.lines.map(&:strip)).to contain_exactly("parent", "child")
    reader.close
  end
end
