require "json"

RSpec.describe "Chronos deploy contract v1" do
  let(:schema) do
    JSON.parse(File.read(File.expand_path("../../contracts/deploy-v1.schema.json", __dir__)))
  end

  it "requires bounded release and correlation fields" do
    expect(schema.fetch("required")).to include(
      "deploy_id", "environment", "revision", "version", "repository", "actor",
      "service", "region", "instance"
    )
    expect(schema.fetch("properties").fetch("repository").fetch("maxLength")).to eq(512)
    expect(schema.fetch("properties").fetch("deploy_id").fetch("maxLength")).to eq(128)
    expect(schema.fetch("anyOf").length).to eq(2)
  end
end
