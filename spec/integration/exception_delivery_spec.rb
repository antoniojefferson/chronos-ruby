RSpec.describe "exception delivery" do
  it "installs in plain Ruby, delivers to a fake server, and shuts down cleanly" do
    server = FakeHttpServer.new("202 Accepted")
    Chronos.configure do |config|
      config.project_id = "project-id"
      config.project_key = "secret-key"
      config.host = server.url
      config.ssl_verify = false
      config.environment = "test"
      config.service_name = "plain-ruby-example"
      config.dependency_reporting = false
      config.timeout = 0.5
      config.open_timeout = 0.5
    end

    expect(Chronos.configured?).to eq(true)
    accepted = Chronos.notify(RuntimeError.new("integration failure"), :context => {"request_id" => "request-1"})
    closed = Chronos.close(1.0)
    server.stop
    body = JSON.parse(server.request_body)

    expect(accepted).to eq(true)
    expect(closed).to eq(true)
    expect(body["payload"]["exception"]["message"]).to eq("integration failure")
    expect(body["context"]["request_id"]).to eq("request-1")
  end
end
