require "benchmark"
require_relative "../lib/chronos/net_http"

# No-op notifier isolating wrapper overhead.
class BenchmarkHttpNotifier
  def external_http_integration_options
    {:enabled => true, :trace_headers => true}
  end

  def propagation_context
    {"trace_id" => "trace-benchmark"}
  end

  def record_event(_type, _payload, _context = {})
    true
  end
end

# Reusable request fixture for the synthetic benchmark.
class BenchmarkHttpRequest
  attr_reader :method

  def initialize
    @method = "GET"
    @headers = {}
  end

  def [](name)
    @headers[name]
  end

  def []=(name, value)
    @headers[name] = value
  end
end

# Connection fixture that performs no socket I/O.
class BenchmarkHttpConnection
  attr_reader :address

  def initialize
    @address = "api.example.test"
    @response = Struct.new(:code).new("200")
  end

  def request(_request, _body = nil)
    @response
  end
end

iterations = Integer(ENV.fetch("ITERATIONS", "100000"))
plain = BenchmarkHttpConnection.new
instrumented = BenchmarkHttpConnection.new
Chronos::Integrations::NetHttp.install(instrumented, :notifier => BenchmarkHttpNotifier.new)
request = BenchmarkHttpRequest.new

plain_elapsed = Benchmark.realtime { iterations.times { plain.request(request) } }
instrumented_elapsed = Benchmark.realtime { iterations.times { instrumented.request(request) } }
overhead = (instrumented_elapsed - plain_elapsed) * 1_000_000 / iterations

puts format("external HTTP wrapper: %.3f microseconds/call (%d iterations)", overhead, iterations)
