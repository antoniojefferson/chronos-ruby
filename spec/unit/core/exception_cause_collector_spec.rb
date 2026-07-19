RSpec.describe Chronos::Core::ExceptionCauseCollector do
  class CyclicCauseError < StandardError
    def cause
      self
    end
  end

  it "stops when an exception cause cycle is found" do
    causes = described_class.new.call(CyclicCauseError.new("cycle"))

    expect(causes.size).to eq(1)
    expect(causes.first["message"]).to eq("cycle")
  end

  it "returns no causes when cause is unavailable" do
    exception = RuntimeError.new("standalone")

    expect(described_class.new.call(exception)).to eq([])
  end
end
