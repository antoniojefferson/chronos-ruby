require "json"

RSpec.describe "Chronos APM batch contract v1" do
  let(:schema) do
    JSON.parse(File.read(File.expand_path("../../contracts/apm-batch-v1.schema.json", __dir__)))
  end

  it "bounds metric batches and defines aggregate statistics" do
    expect(schema.fetch("required")).to include("metrics", "dropped_groups")
    metrics = schema.fetch("properties").fetch("metrics")
    expect(metrics.fetch("maxItems")).to eq(50)
    required = metrics.fetch("items").fetch("required")
    expect(required).to include("metric_type", "dimensions", "count", "duration_ms", "histogram")
    properties = metrics.fetch("items").fetch("properties")
    expect(properties).to include("percentiles_ms", "severity_counts", "diagnostics", "query_analysis", "tracking")
    expect(metrics.fetch("items").fetch("properties").fetch("metric_type").fetch("enum")).to include("external_http")
    diagnostic = properties.fetch("diagnostics").fetch("items")
    expect(diagnostic.fetch("properties").fetch("severity").fetch("enum")).to eq(
      %w(error warning info suggestion)
    )
  end
end
