require "json"

RSpec.describe "Chronos integration verification contract v1" do
  let(:schema) do
    JSON.parse(
      File.read(File.expand_path("../../contracts/integration-verification-response-v1.schema.json", __dir__))
    )
  end

  it "requires a correlated acknowledgement without sensitive receiver details" do
    expect(schema["required"]).to include(
      "verification_id", "credentials_valid", "event_received", "project", "receiver", "error"
    )
    expect(schema["properties"]["status"]["enum"]).to include(
      "accepted", "invalid_credentials", "project_inactive",
      "receiver_unavailable", "receiver_internal_error"
    )
    expect(schema["properties"]["project"]["additionalProperties"]).to eq(false)
    expect(schema["properties"]["receiver"]["additionalProperties"]).to eq(false)
    expect(schema.to_s).not_to include("project_key")
  end
end
