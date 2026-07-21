RSpec.describe "deploy delivery and event correlation" do
  it "delivers a deploy synchronously with matching correlation" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(
      snapshot(
        :app_version => "release-config", :revision => "revision-config",
        :deploy_id => "deploy-config", :service_name => "service",
        :region => "sa-east-1", :instance_id => "web-1"
      ),
      :transport => transport
    )

    result = agent.notify_deploy(
      :environment => "production", :revision => "revision-new", :version => "release-new",
      :repository => "owner/repository", :actor => "release-bot", :deploy_id => "deploy-new"
    )

    expect(result).to eq(true)
    body = JSON.parse(transport.events.first.body)
    expect(body["event_type"]).to eq("deploy")
    expect(body["environment"]).to eq("production")
    expect(body["service"]).to include("name" => "service", "version" => "release-new", "instance_id" => "web-1")
    expect(body["payload"]).to include(
      "deploy_id" => "deploy-new", "revision" => "revision-new", "version" => "release-new",
      "repository" => "owner/repository", "actor" => "release-bot"
    )
    expect(body["correlation"]).to include(
      "release" => "release-new", "revision" => "revision-new", "deploy_id" => "deploy-new",
      "environment" => "production", "service" => "service", "region" => "sa-east-1",
      "instance" => "web-1"
    )
    agent.close(1.0)
  end

  it "adds configured correlation to ordinary exception and telemetry envelopes" do
    config = snapshot(
      :app_version => "release-1", :revision => "revision-1", :deploy_id => "deploy-1",
      :environment => "test", :service_name => "service", :region => "sa-east-1", :instance_id => "web-1"
    )
    notice = Chronos::Core::NoticeBuilder.new(config).call(RuntimeError.new("failed"))
    exception = JSON.parse(Chronos::Core::PayloadSerializer.new(config).call(notice).body)
    event = Chronos::Core::TelemetryEvent.new("cache", "operation" => "cache_read")
    telemetry = JSON.parse(Chronos::Core::TelemetrySerializer.new(config).call(event).body)

    [exception, telemetry].each do |envelope|
      expect(envelope["correlation"]).to include(
        "release" => "release-1", "revision" => "revision-1", "deploy_id" => "deploy-1",
        "environment" => "test", "service" => "service", "region" => "sa-east-1",
        "instance" => "web-1"
      )
    end
  end

  it "bypasses ordinary event sampling" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(
      snapshot(:sampling_rate => 0.0), :transport => transport
    )

    expect(agent.notify_deploy(:revision => "abc123", :version => "release-new")).to eq(true)
    bodies = transport.events.map { |event| JSON.parse(event.body) }
    deploys = bodies.select { |body| body["event_type"] == "deploy" }
    expect(deploys.length).to eq(1)
    agent.close(1.0)
  end

  it "refreshes dependencies once for the deployed release" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(snapshot(:dependency_reporting => true), :transport => transport)

    expect(agent.notify_deploy(:revision => "abc123", :version => "release-new")).to eq(true)
    bodies = transport.events.map { |event| JSON.parse(event.body) }
    dependencies = bodies.select { |body| body["event_type"] == "dependencies" }
    expect(dependencies.length).to eq(1)
    expect(dependencies.first["payload"]["release"]).to eq("release-new")
    agent.close(1.0)
  end
end
