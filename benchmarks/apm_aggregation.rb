require "benchmark"
require "chronos"

config = Chronos::Configuration.new
config.project_id = "benchmark"
config.project_key = "benchmark"
config.host = "https://chronos.invalid"
config.apm_flush_count = 1_000_000
aggregator = Chronos::Application::ApmAggregator.new(config.snapshot)
iterations = Integer(ENV.fetch("ITERATIONS", "100000"))
payload = {
  "operation" => "SELECT", "table" => "accounts", "fingerprint" => "fixed",
  "normalized_query" => "SELECT * FROM accounts WHERE id = ?", "duration_ms" => 12.5
}

elapsed = Benchmark.realtime do
  iterations.times { aggregator.record("query", payload, "trace_id" => "trace") }
end

puts format("apm aggregation: %.3f microseconds/observation (%d iterations, %d groups)",
            elapsed * 1_000_000 / iterations, iterations, aggregator.diagnostics["groups"])
