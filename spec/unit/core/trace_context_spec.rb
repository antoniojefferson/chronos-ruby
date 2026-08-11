RSpec.describe Chronos::Core::TraceContext do
  let(:header) { "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01" }

  it "round-trips valid W3C trace context" do
    context = described_class.parse(header)
    expect(context).to eq("trace_id" => "4bf92f3577b34da6a3ce929d0e0e4736",
                          "span_id" => "00f067aa0ba902b7", "trace_flags" => "01")
    expect(described_class.format(context)).to eq(header)
  end

  it "rejects malformed and all-zero identifiers" do
    expect(described_class.parse("invalid")).to eq({})
    expect(described_class.parse("00-#{'0' * 32}-#{'0' * 16}-00")).to eq({})
  end
end
