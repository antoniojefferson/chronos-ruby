require "benchmark"
require "chronos"

config = Chronos::Configuration.new
config.project_id = "benchmark"
config.project_key = "benchmark"
config.host = "https://chronos.invalid"
config.app_version = "1.2.3"
config.revision = "abc123"
config.deploy_id = "deploy-1"
config.service_name = "billing"
config.region = "sa-east-1"
config.instance_id = "web-1"
correlation = Chronos::Core::CorrelationContext.new(config.snapshot)
iterations = Integer(ENV.fetch("ITERATIONS", "100000"))

elapsed = Benchmark.realtime do
  iterations.times { correlation.call }
end

puts format("correlation context: %.3f microseconds/event (%d iterations)",
            elapsed * 1_000_000 / iterations, iterations)
