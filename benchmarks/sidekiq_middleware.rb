require "benchmark"
require_relative "../lib/chronos/sidekiq"

# No-op notifier that isolates local middleware normalization overhead.
class BenchmarkNotifier
  def propagation_context
    {"trace_id" => "trace-benchmark"}
  end

  def with_context(_context)
    yield
  end

  def record_event(_type, _payload, _context = {})
    true
  end
end

iterations = Integer(ENV.fetch("ITERATIONS", "100000"))
notifier = BenchmarkNotifier.new
client = Chronos::Integrations::Sidekiq::ClientMiddleware.new(:notifier => notifier)
server = Chronos::Integrations::Sidekiq::ServerMiddleware.new(:notifier => notifier)
job = {"class" => "BenchmarkWorker", "jid" => "benchmark-1", "args" => [1, {"name" => "value"}]}

elapsed = Benchmark.realtime do
  iterations.times do
    client.call(Object, job, "default", nil) { true }
    server.call(Object.new, job, "default") { true }
  end
end

puts format("sidekiq middleware: %.3f microseconds/job (%d iterations)",
            elapsed * 1_000_000 / iterations, iterations)
