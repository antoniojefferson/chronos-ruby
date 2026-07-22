RSpec.describe "Chronos integration verification" do
  it "confirms credentials only after the receiver acknowledges the identified fake error" do
    server = FakeHttpServer.new(
      "202 Accepted",
      :response_builder => proc do |request_body, _headers|
        payload = JSON.parse(request_body)
        marker = payload["context"]["integration_verification"]
        JSON.generate(
          "schema_version" => "1.0",
          "success" => true,
          "status" => "accepted",
          "verification_id" => marker["verification_id"],
          "credentials_valid" => true,
          "event_received" => true,
          "event" => {"id" => payload["event_id"]},
          "project" => {
            "id" => "project-id", "name" => "Project",
            "status" => "active", "environment" => "test"
          },
          "receiver" => {
            "name" => "chronos", "status" => "operational",
            "received_at" => "2026-07-22T12:00:00Z"
          },
          "error" => nil
        )
      end
    )
    Chronos.configure do |config|
      config.project_id = "project-id"
      config.project_key = "secret-key"
      config.host = server.url
      config.ssl_verify = false
      config.environment = "test"
      config.dependency_reporting = false
      config.max_retries = 0
    end

    result = Chronos.verify_integration
    server.stop

    expect(result).to be_success
    expect(result.status).to eq("verified")
    expect(result.project).to include("id" => "project-id", "status" => "active")
    expect(result.receiver).to include("name" => "chronos", "status" => "operational")
    expect(server.request_headers["x-chronos-project-key"]).to eq("secret-key")
    expect(server.request_headers["idempotency-key"]).to eq(result.event["id"])
  end
end
