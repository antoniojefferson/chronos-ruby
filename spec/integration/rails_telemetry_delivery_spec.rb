require "chronos/rails"

RSpec.describe "Rails telemetry delivery" do
  it "sanitizes controller parameters and omits raw SQL before asynchronous delivery" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(snapshot, :transport => transport)
    subscriber = Chronos::Rails::NotificationsSubscriber.new(agent, Object.new)

    subscriber.handle(
      "process_action.action_controller",
      ["process_action.action_controller", 1.0, 1.01, "id", {
        :controller => "AccountsController", :action => "show", :status => 200,
        :method => "GET", :path => "/accounts/42?token=raw", :params => {"password" => "secret"}
      }]
    )
    subscriber.handle(
      "sql.active_record",
      ["sql.active_record", 1.0, 1.001, "id", {
        :name => "Account Load", :sql => "SELECT * FROM accounts WHERE token = 'raw-secret'",
        :binds => ["secret-bind"]
      }]
    )

    expect(agent.flush(1.0)).to eq(true)
    bodies = transport.events.map(&:body)
    expect(bodies.size).to eq(1)
    expect(bodies.join).not_to include("secret", "raw-secret", "secret-bind", "?token=raw")
    batch = JSON.parse(bodies.first)
    expect(batch["event_type"]).to eq("metric_batch")
    metrics = batch["payload"]["metrics"]
    request = metrics.find { |metric| metric["metric_type"] == "request" }
    query = metrics.find { |metric| metric["metric_type"] == "query" }
    expect(request).to include("count" => 1, "error_count" => 0)
    expect(query["dimensions"]["normalized_query"]).to eq("SELECT * FROM accounts WHERE token = ?")
    agent.close(1.0)
  end
end
