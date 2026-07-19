require "benchmark"
require "chronos"

iterations = Integer(ENV["ITERATIONS"] || "100000")
queue = Chronos::Internal::BoundedQueue.new(iterations)
event = Chronos::Core::SerializedEvent.new("benchmark", "{}")

elapsed = Benchmark.realtime do
  iterations.times { queue.push(event) }
  iterations.times { queue.pop }
end

operations_per_second = iterations * 2 / elapsed
puts "ruby=#{RUBY_VERSION} iterations=#{iterations} " \
     "total_seconds=#{elapsed} operations_per_second=#{operations_per_second}"
