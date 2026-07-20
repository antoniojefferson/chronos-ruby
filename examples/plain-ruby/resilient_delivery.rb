require "chronos"

# Synthetic transport used only by this executable resilience example.
class ExampleUnavailableTransport
  attr_reader :attempts

  def initialize
    @attempts = 0
  end

  def send_event(_event)
    @attempts += 1
    Chronos::Ports::TransportResult.new(:network_error)
  end

  def send_batch(events)
    events.map { |event| send_event(event) }
  end

  def healthy?
    false
  end

  def close
    true
  end
end

config = Chronos::Configuration.new
config.project_id = "local-resilience"
config.project_key = "synthetic-key"
config.host = "https://chronos.example.test"
config.max_retries = 1
config.retry_base_interval = 0.01
config.retry_jitter = 0.0
config.backlog_size = 2
config.circuit_failure_threshold = 1
transport = ExampleUnavailableTransport.new
agent = Chronos::Agent.new(config.snapshot, :transport => transport)

3.times do |index|
  agent.notify_sync(RuntimeError.new("synthetic failure #{index}"), :parameters => {"password" => "fixture-only"})
end

diagnostics = agent.diagnostics
puts "attempts=#{transport.attempts} backlog=#{diagnostics[:backlog][:size]} " \
     "dropped=#{diagnostics[:states][:dropped]} circuit=#{diagnostics[:circuit]}"
agent.close(0.1)
