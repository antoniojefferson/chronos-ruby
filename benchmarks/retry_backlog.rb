require "benchmark"
require "chronos"

# Constant-time unavailable transport used to measure bounded outage handling.
class UnavailableBenchmarkTransport
  def send_event(_event)
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

iterations = Integer(ENV["ITERATIONS"] || "10000")
config = Chronos::Configuration.new
config.project_id = "benchmark"
config.project_key = "synthetic"
config.host = "https://chronos.example.test"
config.max_retries = 0
config.backlog_size = 100
config.circuit_failure_threshold = 1
pipeline = Chronos::Application::DeliveryPipeline.new(config.snapshot, UnavailableBenchmarkTransport.new)
event = Chronos::Core::SerializedEvent.new("benchmark", "{}")

elapsed = Benchmark.realtime do
  iterations.times { pipeline.deliver_sync(event) }
end

diagnostics = pipeline.diagnostics
puts "ruby=#{RUBY_VERSION} iterations=#{iterations} total_seconds=#{elapsed} " \
     "operations_per_second=#{iterations / elapsed} backlog=#{diagnostics[:backlog][:size]} " \
     "dropped=#{diagnostics[:backlog][:dropped]}"
pipeline.close(0.1)
