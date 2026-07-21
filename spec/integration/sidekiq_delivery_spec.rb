require "chronos/sidekiq"

RSpec.describe "Sidekiq job delivery" do
  class IntegrationSidekiqWorker
    def self.get_sidekiq_options # rubocop:disable Style/AccessorMethodName
      {"tags" => ["payments"]}
    end
  end

  it "sanitizes limited arguments and deduplicates a nested failure" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(snapshot, :transport => transport)
    client = Chronos::Integrations::Sidekiq::ClientMiddleware.new(:notifier => agent)
    server = Chronos::Integrations::Sidekiq::ServerMiddleware.new(:notifier => agent)
    job = {"class" => "IntegrationSidekiqWorker", "jid" => "jid-1",
           "args" => [{"password" => "secret", "token" => "private"}]}
    client.call(IntegrationSidekiqWorker, job, "critical", nil) { true }
    error = RuntimeError.new("job failed")

    expect do
      server.call(IntegrationSidekiqWorker.new, job, "critical") do
        agent.notify_once(error, :context => {"source" => "active_job"})
        raise error
      end
    end.to raise_error(error)

    expect(agent.flush(1.0)).to eq(true)
    bodies = transport.events.map { |event| JSON.parse(event.body) }
    expect(bodies.count { |body| body["event_type"] == "exception" }).to eq(1)
    exception = bodies.find { |body| body["event_type"] == "exception" }
    expect(exception["payload"]["parameters"]["arguments"].first).to eq(
      "password" => "[FILTERED]", "token" => "[FILTERED]"
    )
    batch = bodies.find { |body| body["event_type"] == "metric_batch" }
    job_metric = batch["payload"]["metrics"].find { |metric| metric["metric_type"] == "job" }
    expect(job_metric).to include("count" => 1, "error_count" => 1)
    expect(job_metric["dimensions"]).to include(
      "class" => "IntegrationSidekiqWorker", "queue" => "critical", "status" => "failed"
    )
    agent.close(1.0)
  end
end
