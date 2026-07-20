RSpec.describe Chronos::Core::BreadcrumbBuffer do
  it "keeps only the newest bounded, normalized breadcrumbs" do
    buffer = described_class.new(2, 256)
    buffer.add(:category => "custom", :message => "one", :metadata => {"object" => Object.new})
    buffer.add(:category => "query", :message => "two", :metadata => {"sql" => "select 1"})
    buffer.add(:category => "unknown", :message => "three", :metadata => {"body" => "x" * 2_000})

    expect(buffer.size).to eq(2)
    expect(buffer.to_a.map { |item| item["message"] }).to eq(%w(two three))
    expect(buffer.to_a.last["category"]).to eq("custom")
    expect(JSON.generate(buffer.to_a.last).bytesize).to be <= 256
  end

  it "honors the smallest configurable byte limit" do
    buffer = described_class.new(1, 128)
    buffer.add(:message => "x" * 2_000, :metadata => {"body" => "y" * 2_000})

    expect(JSON.generate(buffer.to_a.first).bytesize).to be <= 128
  end
end
