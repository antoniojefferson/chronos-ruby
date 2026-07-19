RSpec.describe Chronos::Core::NoticeBuilder do
  it "constructs an immutable notice without a backtrace" do
    builder = described_class.new(snapshot, proc { Time.utc(2026, 1, 2, 3, 4, 5) })
    notice = builder.call(RuntimeError.new("failed"), :user => {"id" => "42"})

    expect(notice.exception_class).to eq("RuntimeError")
    expect(notice.backtrace).to eq([])
    expect(notice.user).to eq("id" => "42")
    expect(notice.timestamp).to start_with("2026-01-02T03:04:05")
    expect(notice).to be_frozen
    expect(notice.user).to be_frozen
  end

  it "rejects values that are not exceptions" do
    expect { described_class.new(snapshot).call("failure") }.to raise_error(ArgumentError)
  end
end
