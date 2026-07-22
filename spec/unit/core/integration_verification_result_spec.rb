RSpec.describe Chronos::Core::IntegrationVerificationResult do
  it "returns an immutable bounded JSON-safe result" do
    project = {"id" => "project-id", "name" => "Project", "unknown" => Object.new}
    result = described_class.new(
      :success => true,
      :status => "verified",
      :verification_id => "verification-id",
      :credentials_valid => true,
      :event => {"id" => "event-id", "received" => true},
      :project => project,
      :receiver => {"name" => "chronos", "status" => "operational"}
    )

    expect(result).to be_success
    expect(result).to be_frozen
    expect(result.project).to be_frozen
    expect(project).not_to be_frozen
    expect(JSON.parse(result.to_json)).to include(
      "schema_version" => "1.0", "success" => true, "status" => "verified"
    )
    expect(result.to_json).not_to include("#<Object")
  end
end
