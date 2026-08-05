require "benchmark"
require "chronos"

iterations = Integer(ENV.fetch("ITERATIONS", "100000"))
warmup = Integer(ENV.fetch("WARMUP", "5000"))
sql = "SELECT * FROM payments WHERE account_id = 42 AND status = 'pending' ORDER BY created_at DESC"
normalizer = Chronos::Core::SqlNormalizer.new
analyzer = Chronos::Core::SqlQueryAnalyzer.new
normalized = normalizer.call(sql, :adapter => "PostgreSQL")

warmup.times do
  normalizer.call(sql)
  analyzer.call(normalized)
end

normalization = Benchmark.realtime { iterations.times { normalizer.call(sql) } }
analysis = Benchmark.realtime { iterations.times { analyzer.call(normalized) } }

puts format("normalization: %.3f microseconds/iteration", normalization * 1_000_000 / iterations)
puts format("static query analysis: %.3f microseconds/iteration", analysis * 1_000_000 / iterations)
puts "iterations=#{iterations} warmup=#{warmup} database_inspection=false"
