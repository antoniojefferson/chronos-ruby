require "json"

RSpec.describe "Chronos dependencies contract v1" do
  it "bounds dependency inventory fields" do
    path = File.expand_path("../../contracts/dependencies-v1.schema.json", __dir__)
    schema = JSON.parse(File.read(path))

    expect(schema.fetch("required")).to include("dependencies", "ruby")
    expect(schema.fetch("properties").fetch("dependencies").fetch("maxItems")).to eq(200)
    expect(schema.fetch("properties").fetch("dependencies").fetch("items").fetch("required")).to eq(%w(name version))
    expect(schema.fetch("properties").fetch("ruby").fetch("required")).to eq(%w(version engine platform))
  end
end
