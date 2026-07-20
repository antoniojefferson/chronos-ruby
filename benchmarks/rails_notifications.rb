require "benchmark"
require "chronos/rails"

# No-op capture target used to isolate subscriber normalization overhead.
class RailsBenchmarkNotifier
  def record_event(_type, _payload, _context = {})
    true
  end

  def notify_once(_exception, _context = {})
    true
  end
end

iterations = Integer(ENV.fetch("ITERATIONS", "100000"))
subscriber = Chronos::Rails::NotificationsSubscriber.new(RailsBenchmarkNotifier.new, Object.new)
arguments = [
  "sql.active_record", 1.0, 1.0005, "id",
  {:name => "Account Load", :sql => "SELECT * FROM accounts", :binds => ["private"]}
]

elapsed = Benchmark.realtime do
  iterations.times { subscriber.handle("sql.active_record", arguments) }
end

puts "iterations=#{iterations} elapsed_seconds=#{elapsed.round(6)}"
puts "subscriber_microseconds=#{(elapsed * 1_000_000.0 / iterations).round(3)}"
