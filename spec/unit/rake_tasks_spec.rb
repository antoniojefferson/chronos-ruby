require "rake"
require "stringio"
require "chronos/rake_tasks"

RSpec.describe Chronos::RakeTasks do
  around do |example|
    previous = Rake.application
    Rake.application = Rake::Application.new
    begin
      example.run
    ensure
      Rake.application = previous
    end
  end

  def result(success, status)
    Chronos::Core::IntegrationVerificationResult.new(
      :success => success,
      :status => status,
      :credentials_valid => success,
      :event => {"id" => "event-id", "received" => success}
    )
  end

  it "prints one JSON result and succeeds after the Rails environment is loaded" do
    output = StringIO.new
    environment_loaded = false
    Rake::Task.define_task("environment") { environment_loaded = true }
    allow(Chronos).to receive(:verify_integration).and_return(result(true, "verified"))

    described_class.install(:output => output)
    Rake::Task[described_class::TASK_NAME].invoke

    expect(environment_loaded).to eq(true)
    expect(JSON.parse(output.string)).to include("success" => true, "status" => "verified")
  end

  it "prints structured failure JSON and exits nonzero" do
    output = StringIO.new
    statuses = []
    allow(Chronos).to receive(:verify_integration).and_return(result(false, "invalid_credentials"))

    described_class.install(:output => output, :exit => proc { |status| statuses << status })
    Rake::Task[described_class::TASK_NAME].invoke

    expect(statuses).to eq([1])
    expect(JSON.parse(output.string)).to include(
      "success" => false, "status" => "invalid_credentials", "credentials_valid" => false
    )
  end
end
