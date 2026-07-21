require "chronos/rails"

RSpec.describe "cache telemetry delivery" do
  it "delivers a project-scoped key hash without the raw cache key" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(snapshot(:cache_key_mode => :sha256), :transport => transport)
    subscriber = Chronos::Rails::NotificationsSubscriber.new(agent)

    subscriber.handle(
      "cache_read.active_support",
      ["cache_read.active_support", 1.0, 1.005, "event-id",
       {:key => "customer:42:private", :store => "Redis", :namespace => "accounts", :hit => false}]
    )
    expect(agent.flush(1.0)).to eq(true)

    body = JSON.parse(transport.events.first.body)
    expect(body["event_type"]).to eq("cache")
    expect(body["payload"]).to include(
      "operation" => "cache_read", "backend" => "Redis", "namespace" => "accounts",
      "hit" => false, "outcome" => "miss", "duration_ms" => 5.0
    )
    expect(body["payload"]["key_hash"]).to match(/\A[0-9a-f]{64}\z/)
    expect(body.to_s).not_to include("customer:42:private")
    agent.close(1.0)
  end
end
