require "json"

RSpec.describe "Sidekiq job contract v1" do
  it "documents the bounded fields emitted by the legacy middleware" do
    path = File.expand_path("../../contracts/sidekiq-job-v1.schema.json", __dir__)
    schema = JSON.parse(File.read(path))

    expect(schema.fetch("required")).to include("kind", "class", "queue", "duration_ms", "status")
    expect(schema.fetch("properties").fetch("kind").fetch("const")).to eq("sidekiq")
    expect(schema.fetch("properties").fetch("arguments").fetch("maxItems")).to eq(20)
    expect(schema.fetch("properties").fetch("status").fetch("enum")).to eq(%w(completed failed))
  end
end
