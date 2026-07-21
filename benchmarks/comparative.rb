require "benchmark"
require "chronos"

# No-op notifier isolating Rack middleware overhead from network delivery.
class ComparativeNotifier
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

def median(values)
  ordered = values.sort
  middle = ordered.length / 2
  ordered.length.odd? ? ordered[middle] : (ordered[middle - 1] + ordered[middle]) / 2.0
end

def dispersion(values, center)
  median(values.map { |value| (value - center).abs })
end

iterations = Integer(ENV.fetch("ITERATIONS", "50000"))
warmup = Integer(ENV.fetch("WARMUP", "5000"))
samples = Integer(ENV.fetch("SAMPLES", "7"))
raise "SAMPLES must be at least 3" if samples < 3

app = proc { |_env| [200, {"Content-Length" => "2"}, ["ok"]] }
instrumented = Chronos::Integrations::Rack::Middleware.new(app, :notifier => ComparativeNotifier.new)
env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/benchmark", "HTTP_HOST" => "example.test"}

warmup.times { app.call(env) }
warmup.times { instrumented.call(env) }

direct_samples = []
instrumented_samples = []
samples.times do
  direct_samples << Benchmark.realtime { iterations.times { app.call(env) } }
  instrumented_samples << Benchmark.realtime { iterations.times { instrumented.call(env) } }
end

direct = median(direct_samples)
chronos = median(instrumented_samples)
overhead = (chronos - direct) * 1_000_000.0 / iterations

puts "ruby=#{RUBY_VERSION} iterations=#{iterations} warmup=#{warmup} samples=#{samples}"
puts "direct_median_seconds=#{direct.round(6)} direct_mad_seconds=#{dispersion(direct_samples, direct).round(6)}"
chronos_dispersion = dispersion(instrumented_samples, chronos)
puts "chronos_median_seconds=#{chronos.round(6)} chronos_mad_seconds=#{chronos_dispersion.round(6)}"
puts "median_overhead_microseconds_per_request=#{overhead.round(3)}"
