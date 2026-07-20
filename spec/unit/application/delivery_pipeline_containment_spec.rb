RSpec.describe Chronos::Application::DeliveryPipeline, "failure containment" do
  it "contains invalid direct delivery input without leaking it into backlog" do
    pipeline = described_class.new(snapshot, FakeTransport.new)

    expect { pipeline.deliver_sync("raw event") }.not_to raise_error
    expect(pipeline.deliver_sync("raw event")).to eq(false)
    expect(pipeline.diagnostics[:backlog][:size]).to eq(0)
    pipeline.close(0.1)
  end
end
