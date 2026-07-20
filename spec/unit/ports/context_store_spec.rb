RSpec.describe Chronos::Ports::ContextStore do
  it "accepts only objects implementing the complete execution-context contract" do
    store = Chronos::Adapters::ThreadLocalContextStore.new

    expect(described_class.compatible?(store)).to eq(true)
    expect(described_class.compatible?(Object.new)).to eq(false)
  end
end
