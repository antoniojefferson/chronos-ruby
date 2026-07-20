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
        :name => "Account Load", :sql => "SELECT private FROM accounts", :binds => ["secret-bind"]
      }]
    )

    expect(agent.flush(1.0)).to eq(true)
    bodies = transport.events.map(&:body)
    expect(bodies.size).to eq(2)
    expect(bodies.join).not_to include("secret", "SELECT private", "secret-bind", "?token=raw")
    request = JSON.parse(bodies.find { |body| JSON.parse(body)["event_type"] == "request" })
    expect(request["payload"]["parameters"]["password"]).to eq("[FILTERED]")
    agent.close(1.0)
  end
end
