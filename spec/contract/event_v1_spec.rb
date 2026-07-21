RSpec.describe "Chronos event contract v1" do
  let(:schema) do
    JSON.parse(File.read(File.expand_path("../../contracts/event-v1.schema.json", __dir__)))
  end

  it "contains every required envelope field" do
    notice = Chronos::Core::NoticeBuilder.new(snapshot).call(RuntimeError.new("failed"))
    event = Chronos::Core::PayloadSerializer.new(snapshot).call(notice)
    payload = JSON.parse(event.body)

    expect(payload.keys).to include(*schema["required"])
    expect(schema["required"]).not_to include("correlation")
    expect(payload["schema_version"]).to eq("1.0")
    expect(payload["payload"]["exception"].keys).to include("class", "message", "backtrace", "causes")
    expect(payload["correlation"].keys).to include(
      "release", "revision", "deploy_id", "environment", "service", "region", "instance"
    )
  end

  it "does not place the secret project key in the payload" do
    notice = Chronos::Core::NoticeBuilder.new(snapshot).call(RuntimeError.new("failed"))
    body = Chronos::Core::PayloadSerializer.new(snapshot).call(notice).body

    expect(body).not_to include("project-key")
  end

  it "declares every supported telemetry event type" do
    types = schema["properties"]["event_type"]["enum"]

    expect(types).to include(
      "exception", "request", "query", "job", "cache", "external_http", "dependencies", "deploy", "metric_batch"
    )
  end
end
