RSpec.describe "Chronos event contract v1" do
  let(:schema) do
    JSON.parse(File.read(File.expand_path("../../contracts/event-v1.schema.json", __dir__)))
  end

  it "contains every required envelope field" do
    notice = Chronos::Core::NoticeBuilder.new(snapshot).call(RuntimeError.new("failed"))
    event = Chronos::Core::PayloadSerializer.new(snapshot).call(notice)
    payload = JSON.parse(event.body)

    expect(payload.keys).to include(*schema["required"])
    expect(payload["schema_version"]).to eq("1.0")
    expect(payload["payload"]["exception"].keys).to include("class", "message", "backtrace", "causes")
  end

  it "does not place the secret project key in the payload" do
    notice = Chronos::Core::NoticeBuilder.new(snapshot).call(RuntimeError.new("failed"))
    body = Chronos::Core::PayloadSerializer.new(snapshot).call(notice).body

    expect(body).not_to include("project-key")
  end

  it "declares the Rails telemetry event types" do
    types = schema["properties"]["event_type"]["enum"]

    expect(types).to include("exception", "request", "query", "job", "cache", "metric_batch")
  end
end
