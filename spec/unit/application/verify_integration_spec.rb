RSpec.describe Chronos::Application::VerifyIntegration do # rubocop:disable Metrics/BlockLength
  class VerificationTransport < FakeTransport
    def initialize(status = :success, status_code = 202, &response_builder)
      super()
      @status = status
      @status_code = status_code
      @response_builder = response_builder
    end

    def send_event(event)
      @events << event
      response = @response_builder && @response_builder.call(event)
      Chronos::Ports::TransportResult.new(
        @status, :status_code => @status_code, :response => response
      )
    end
  end

  def config(overrides = {})
    snapshot({:max_retries => 0, :dependency_reporting => false}.merge(overrides))
  end

  def verifier(transport, overrides = {})
    settings = config(overrides)
    pipeline = Chronos::Application::DeliveryPipeline.new(settings, transport)
    described_class.new(
      settings, pipeline, nil, :uuid_generator => proc { "verification-id" }
    )
  end

  def accepted_response(event)
    payload = JSON.parse(event.body)
    marker = payload["context"]["integration_verification"]
    {
      "schema_version" => "1.0",
      "success" => true,
      "status" => "accepted",
      "verification_id" => marker["verification_id"],
      "credentials_valid" => true,
      "event_received" => true,
      "event" => {"id" => event.event_id},
      "project" => {
        "id" => "project-id", "name" => "Chronos Project",
        "status" => "active", "environment" => "test"
      },
      "receiver" => {
        "name" => "chronos", "status" => "operational",
        "received_at" => "2026-07-22T12:00:00Z"
      },
      "error" => nil
    }
  end

  it "sends an identified fake exception and accepts a correlated acknowledgement" do
    transport = VerificationTransport.new { |event| accepted_response(event) }
    result = verifier(transport).call
    payload = JSON.parse(transport.events.first.body)

    expect(result).to be_success
    expect(result.status).to eq("verified")
    expect(result.credentials_valid).to eq(true)
    expect(result.event).to include("received" => true)
    expect(payload["event_type"]).to eq("exception")
    expect(payload["payload"]["exception"]["class"]).to eq("Chronos::IntegrationVerificationError")
    expect(payload["payload"]["tags"]).to include("chronos-integration-verification")
    expect(payload["context"]["integration_verification"]).to include(
      "verification_id" => "verification-id", "kind" => "integration_verification", "test" => true
    )
    expect(transport.events.first.body).not_to include("project-key")
  end

  it "rejects an uncorrelated successful response" do
    transport = VerificationTransport.new do |event|
      accepted_response(event).merge("verification_id" => "different-id")
    end

    result = verifier(transport).call

    expect(result).not_to be_success
    expect(result.status).to eq("invalid_response")
    expect(result.credentials_valid).to be_nil
  end

  it "rejects successful responses containing fields outside the contract" do
    transport = VerificationTransport.new do |event|
      accepted_response(event).merge("internal_path" => "/private/chronos/app")
    end

    result = verifier(transport).call

    expect(result.status).to eq("invalid_response")
    expect(result.to_json).not_to include("internal_path")
  end

  it "classifies invalid credentials without exposing the response" do
    transport = VerificationTransport.new(:client_error, 401) do |_event|
      {"error" => {"message" => "database and file details"}}
    end

    result = verifier(transport).call

    expect(result.status).to eq("invalid_credentials")
    expect(result.credentials_valid).to eq(false)
    expect(result.to_json).not_to include("database and file details")
  end

  it "distinguishes an authenticated but inactive project" do
    transport = VerificationTransport.new(:client_error, 403) do |event|
      accepted_response(event).merge(
        "success" => false, "status" => "project_inactive", "event_received" => false,
        "credentials_valid" => true,
        "project" => {
          "id" => "project-id", "name" => "Project", "status" => "inactive", "environment" => "test"
        },
        "receiver" => {"name" => "chronos", "status" => "operational", "received_at" => nil},
        "error" => {
          "code" => "project_inactive", "message" => "Project is inactive.",
          "guidance" => "Activate the project or select an active project."
        }
      )
    end

    result = verifier(transport).call

    expect(result.status).to eq("project_inactive")
    expect(result.credentials_valid).to eq(true)
    expect(result.event["received"]).to eq(false)
  end

  it "distinguishes receiver internal errors from unavailability" do
    internal = verifier(VerificationTransport.new(:server_error, 500)).call
    unavailable = verifier(VerificationTransport.new(:server_error, 503)).call
    network = verifier(VerificationTransport.new(:network_error, nil)).call

    expect(internal.status).to eq("receiver_internal_error")
    expect(unavailable.status).to eq("receiver_unavailable")
    expect(network.status).to eq("receiver_unavailable")
  end
end
