require "benchmark"
require "chronos"

# In-memory transport used to isolate local capture overhead from network time.
class BenchmarkTransport
  RESULT = Chronos::Ports::TransportResult.new(:success, :status_code => 202)

  def send_event(_event)
    RESULT
  end

  def send_batch(events)
    events.map { RESULT }
  end

  def healthy?
    true
  end

  def close
    true
  end
end

config = Chronos::Configuration.new
config.project_id = "benchmark"
config.project_key = "benchmark"
config.host = "https://chronos.invalid"
iterations = Integer(ENV["ITERATIONS"] || "10000")
config.queue_size = iterations + 100
agent = Chronos::Agent.new(config.snapshot, :transport => BenchmarkTransport.new)
exception = RuntimeError.new("benchmark failure")
exception.set_backtrace(["app/service.rb:42:in `call'"])

100.times { agent.notify(exception) }
agent.flush(2.0)

elapsed = Benchmark.realtime do
  iterations.times { agent.notify(exception) }
  agent.flush(10.0)
end

agent.close(2.0)
microseconds = elapsed * 1_000_000 / iterations
puts "ruby=#{RUBY_VERSION} iterations=#{iterations} " \
     "total_seconds=#{elapsed} microseconds_per_capture=#{microseconds}"
