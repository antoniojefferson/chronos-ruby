RSpec.describe "dependency inventory delivery" do
  class OneDependencyReporter
    def initialize
      @reported = false
    end

    def call
      return nil if @reported

      @reported = true
      {"dependencies" => [{"name" => "rack", "version" => "1.6.13"}], "release" => "release-1"}
    end
  end

  it "sends the inventory only once per agent" do
    transport = FakeTransport.new
    agent = Chronos::Agent.new(
      snapshot(:dependency_reporting => true),
      :transport => transport, :dependency_reporter => OneDependencyReporter.new
    )

    expect(agent.report_dependencies).to eq(true)
    expect(agent.report_dependencies).to eq(false)
    expect(agent.flush(1.0)).to eq(true)
    payloads = transport.events.map { |event| JSON.parse(event.body) }
    expect(payloads.count { |payload| payload["event_type"] == "dependencies" }).to eq(1)
    expect(payloads.first["payload"]["dependencies"]).to eq([{"name" => "rack", "version" => "1.6.13"}])
    agent.close(1.0)
  end
end
