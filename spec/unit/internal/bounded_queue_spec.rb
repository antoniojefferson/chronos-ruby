RSpec.describe Chronos::Internal::BoundedQueue do
  it "drops the newest item without blocking when full" do
    queue = described_class.new(1)

    expect(queue.push(:first)).to eq(true)
    expect(queue.push(:second)).to eq(false)
    expect(queue.pop).to eq(:first)
    expect(queue.stats).to include(:accepted => 1, :dropped => 1)
  end

  it "wakes waiting consumers when closed" do
    queue = described_class.new(1)
    result = nil
    thread = Thread.new { result = queue.pop }
    sleep(0.01)

    queue.close
    thread.join(0.5)

    expect(result).to eq(nil)
    expect(thread).not_to be_alive
  end

  it "rejects items after close" do
    queue = described_class.new(1)
    queue.close

    expect(queue.push(:event)).to eq(false)
  end
end
