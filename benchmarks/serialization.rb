require "benchmark"
require "chronos"

config = Chronos::Configuration.new
config.project_id = "benchmark"
config.project_key = "benchmark"
config.host = "https://chronos.invalid"
snapshot = config.snapshot
builder = Chronos::Core::NoticeBuilder.new(snapshot)
serializer = Chronos::Core::PayloadSerializer.new(snapshot)
exception = RuntimeError.new("benchmark failure")
exception.set_backtrace(Array.new(20) { |index| "app/service.rb:#{index + 1}:in `call'" })
notice = builder.call(exception, :context => {"operation" => "benchmark"})
iterations = Integer(ENV["ITERATIONS"] || "10000")

100.times { serializer.call(notice) }
elapsed = Benchmark.realtime { iterations.times { serializer.call(notice) } }

microseconds = elapsed * 1_000_000 / iterations
puts "ruby=#{RUBY_VERSION} iterations=#{iterations} " \
     "total_seconds=#{elapsed} microseconds_per_serialization=#{microseconds}"
