RSpec.describe Chronos::Adapters::FiberLocalContextStore do
  it "restores nested execution context" do
    store = described_class.new
    store.with_context(:request_id => "outer") do
      store.with_context(:user => "42") do
        expect(store.get).to include(:request_id => "outer", :user => "42")
      end
      expect(store.get).to eq(:request_id => "outer")
    end
    expect(store.get).to eq({})
  end
end
