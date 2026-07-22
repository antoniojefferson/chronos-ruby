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

  it "does not freeze strings or containers owned by the caller" do
    message = String.new("failed")
    user_id = String.new("42")
    user_key = String.new("id")
    user = {user_key => user_id}
    tags = [String.new("login")]
    notice = described_class.new(snapshot).call(RuntimeError.new(message), :user => user, :tags => tags)

    expect(notice.message).to eq("failed")
    expect(notice.message).to be_frozen
    expect(notice.user).to be_frozen
    expect(notice.user.keys.first).to be_frozen
    expect(notice.user.values.first).to be_frozen
    expect(notice.tags).to be_frozen

    expect(message).not_to be_frozen
    expect(user).not_to be_frozen
    expect(user_key).not_to be_frozen
    expect(user_id).not_to be_frozen
    expect(tags).not_to be_frozen
    expect(tags.first).not_to be_frozen
  end

  it "rejects values that are not exceptions" do
    expect { described_class.new(snapshot).call("failure") }.to raise_error(ArgumentError)
  end
end
