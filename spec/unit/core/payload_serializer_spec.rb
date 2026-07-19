RSpec.describe Chronos::Core::PayloadSerializer do
  class DangerousJsonObject
    def to_json(*)
      raise "must not be called"
    end
  end

  def build_notice(context = {})
    Chronos::Core::NoticeBuilder.new(snapshot).call(RuntimeError.new("failed"), context)
  end

  it "creates the versioned exception envelope" do
    event = described_class.new(snapshot).call(build_notice(:context => {"request_id" => "abc"}))
    payload = JSON.parse(event.body)

    expect(payload["schema_version"]).to eq("1.0")
    expect(payload["event_type"]).to eq("exception")
    expect(payload["project_key"]).to eq("project-id")
    expect(payload["context"]["request_id"]).to eq("abc")
  end

  it "does not invoke arbitrary object serialization" do
    event = described_class.new(snapshot).call(build_notice(:context => {"object" => DangerousJsonObject.new}))

    expect(event.body).to include("DangerousJsonObject")
  end

  it "replaces invalid string encoding" do
    invalid = "message".dup
    invalid.force_encoding("UTF-8")
    invalid.setbyte(0, 255)
    event = described_class.new(snapshot).call(build_notice(:context => {"invalid" => invalid}))

    expect { JSON.parse(event.body) }.not_to raise_error
  end

  it "replaces invalid encoding in the exception message" do
    invalid = "message".dup
    invalid.force_encoding("UTF-8")
    invalid.setbyte(0, 255)
    notice = Chronos::Core::NoticeBuilder.new(snapshot).call(RuntimeError.new(invalid))
    event = described_class.new(snapshot).call(notice)

    expect { JSON.parse(event.body) }.not_to raise_error
  end

  it "rejects a payload that cannot fit after bounded compaction" do
    small_config = snapshot(:max_payload_size => 100)
    notice = Chronos::Core::NoticeBuilder.new(small_config).call(RuntimeError.new("failed"))

    expect { described_class.new(small_config).call(notice) }.to raise_error(Chronos::Error, /max_payload_size/)
  end
end
