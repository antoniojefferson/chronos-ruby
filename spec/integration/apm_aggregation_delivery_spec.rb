require "chronos/rails"

RSpec.describe "APM aggregation delivery" do
  it "sends bounded request and SQL aggregates instead of one event per observation" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(snapshot(:apm_flush_count => 100), :transport => transport)
    subscriber = Chronos::Rails::NotificationsSubscriber.new(agent, Object.new)

    3.times do |index|
      subscriber.handle(
        "sql.active_record",
        ["sql.active_record", 1.0, 1.075, "id", {
          :name => "Account Load", :sql => "SELECT * FROM accounts WHERE id = #{index + 1}",
          :binds => ["secret"], :cached => false, :connection_role => :reading
        }]
      )
    end
    subscriber.handle(
      "process_action.action_controller",
      ["process_action.action_controller", 1.0, 1.4, "id", {
        :controller => "AccountsController", :action => "index", :status => 200,
        :method => "GET", :path => "/accounts", :params => {"token" => "secret"}
      }]
    )

    expect(transport.events).to be_empty
    expect(agent.flush(1.0)).to eq(true)
    expect(transport.events.length).to eq(1)
    envelope = JSON.parse(transport.events.first.body)
    expect(envelope["event_type"]).to eq("metric_batch")
    expect(envelope.to_s).not_to include("secret", "id = 1", "id = 2", "id = 3")
    query = envelope["payload"]["metrics"].find { |metric| metric["metric_type"] == "query" }
    expect(query["count"]).to eq(3)
    expect(query["dimensions"]).to include(
      "operation" => "SELECT", "table" => "accounts", "role" => "reading"
    )
    agent.close(1.0)
  end
end
