RSpec.describe "Chronos Rack context contract v1" do
  let(:schema) do
    path = File.expand_path("../../contracts/rack-context-v1.schema.json", __dir__)
    JSON.parse(File.read(path))
  end

  it "requires isolated request, trace, and breadcrumb fields" do
    expect(schema["required"]).to contain_exactly("request", "trace_id", "breadcrumbs")
    request = schema["properties"]["request"]
    expect(request["required"]).to include(
      "method", "route", "status", "duration_ms", "request_id", "host", "path"
    )
    expect(schema["properties"]["breadcrumbs"]["items"]["properties"]["category"]["enum"]).to include(
      "custom", "log", "request", "query", "external_http", "cache", "job"
    )
  end
end
