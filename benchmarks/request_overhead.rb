require "benchmark"
require "chronos"

# Minimal notifier that measures middleware work without capture or network I/O.
class BenchmarkNotifier
  def with_context(_context)
    yield
  end

  def add_breadcrumb(_attributes)
    true
  end

  def notify(_error, _context)
    true
  end
end

iterations = Integer(ENV.fetch("ITERATIONS", "100000"))
app = proc { |_env| [200, {"Content-Length" => "2"}, ["ok"]] }
middleware = Chronos::Integrations::Rack::Middleware.new(app, :notifier => BenchmarkNotifier.new)
env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/accounts/42", "HTTP_HOST" => "example.test"}

direct = Benchmark.realtime { iterations.times { app.call(env) } }
instrumented = Benchmark.realtime { iterations.times { middleware.call(env) } }
overhead = instrumented - direct

puts "iterations=#{iterations} direct_seconds=#{direct.round(6)} instrumented_seconds=#{instrumented.round(6)}"
puts "middleware_overhead_microseconds=#{(overhead * 1_000_000.0 / iterations).round(3)}"
