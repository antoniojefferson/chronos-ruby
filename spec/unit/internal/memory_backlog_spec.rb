RSpec.describe Chronos::Internal::MemoryBacklog do
  def event(id)
    Chronos::Core::SerializedEvent.new(id, "{\"password\":\"[FILTERED]\"}")
  end

  it "keeps a fixed number of sanitized serialized events" do
    backlog = described_class.new(2)

    expect(backlog.push(event("one"))).to eq(true)
    expect(backlog.push(event("two"))).to eq(true)
    expect(backlog.push(event("three"))).to eq(false)
    expect(backlog.stats).to eq(:size => 2, :capacity => 2, :accepted => 2, :dropped => 1)
    expect(backlog.shift.event_id).to eq("one")
  end

  it "rejects raw objects before they can enter retry storage" do
    backlog = described_class.new(1)

    expect { backlog.push("password" => "secret") }.to raise_error(ArgumentError)
    expect(backlog.size).to eq(0)
  end
end
