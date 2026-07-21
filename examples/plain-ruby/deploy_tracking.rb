#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "json"
require "chronos"

# In-memory transport keeps this correlation example network-free.
class ExampleDeployTransport
  attr_reader :events

  def initialize
    @events = []
  end

  def send_event(event)
    @events << event
    Chronos::Ports::TransportResult.new(:success, :status_code => 202)
  end

  def send_batch(events)
    events.map { |event| send_event(event) }
  end

  def healthy?
    true
  end

  def close
    true
  end
end

config = Chronos::Configuration.new
config.project_id = "example"
config.project_key = "not-sent"
config.host = "https://chronos.example.test"
config.environment = "production"
config.service_name = "billing"
config.dependency_reporting = false
transport = ExampleDeployTransport.new
agent = Chronos::Agent.new(config.snapshot, :transport => transport)

agent.notify_deploy(
  :revision => "abc123", :version => "1.2.3", :repository => "owner/repository",
  :actor => "release-bot", :deploy_id => "deploy-example", :region => "sa-east-1",
  :instance => "web-1"
)
puts JSON.pretty_generate(JSON.parse(transport.events.first.body))
agent.close(1.0)
