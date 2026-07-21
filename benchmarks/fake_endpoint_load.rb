require "benchmark"
require "json"
require "socket"
require "chronos"

# Local bounded HTTP endpoint used by the release load gate.
class LoadEndpoint
  attr_reader :received, :invalid

  def initialize(expected)
    @expected = expected
    @received = 0
    @invalid = 0
    @mutex = Mutex.new
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @thread = Thread.new { serve }
  end

  def url
    "http://127.0.0.1:#{@port}"
  end

  def wait(timeout)
    @thread.join(timeout)
    !@thread.alive?
  end

  def close
    @server.close unless @server.closed?
    @thread.kill if @thread.alive?
  rescue IOError, Errno::EBADF
    nil
  end

  private

  def serve
    while @mutex.synchronize { @received < @expected }
      client = @server.accept
      handle(client)
    end
  rescue IOError, Errno::EBADF
    nil
  ensure
    @server.close unless @server.closed?
  end

  def handle(client)
    body = read_body(client)
    @mutex.synchronize do
      @received += 1
      @invalid += 1 unless valid_payload?(body)
    end
    write_response(client)
  rescue StandardError
    @mutex.synchronize do
      @received += 1
      @invalid += 1
    end
  ensure
    client.close if client && !client.closed?
  end

  def read_body(client)
    headers = {}
    client.gets
    while (line = client.gets)
      break if line == "\r\n"
      key, value = line.split(":", 2)
      headers[key.to_s.downcase] = value.to_s.strip
    end
    client.read(headers["content-length"].to_i)
  end

  def valid_payload?(body)
    payload = JSON.parse(body)
    payload["schema_version"] == "1.0" && payload["project_key"] == "load-test" &&
      !body.include?("synthetic-secret")
  rescue StandardError
    false
  end

  def write_response(client)
    client.write("HTTP/1.1 202 Accepted\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}")
  rescue IOError, Errno::ECONNRESET, Errno::EPIPE
    nil
  end
end

iterations = Integer(ENV.fetch("ITERATIONS", "500"))
endpoint = LoadEndpoint.new(iterations)
config = Chronos::Configuration.new
config.project_id = "load-test"
config.project_key = "synthetic-secret"
config.host = endpoint.url
config.ssl_verify = false
config.dependency_reporting = false
config.queue_size = iterations
config.workers = 2
agent = Chronos::Agent.new(config.snapshot)
error = RuntimeError.new("synthetic load failure")
error.set_backtrace(["app/load.rb:1:in `call'"])

elapsed = Benchmark.realtime do
  iterations.times do
    raise "queue rejected load event" unless agent.notify(error)
  end
  raise "flush timed out" unless agent.flush(30.0)
end

raise "endpoint did not receive every event" unless endpoint.wait(5.0)
raise "endpoint received invalid payloads" unless endpoint.invalid.zero?

puts "ruby=#{RUBY_VERSION} events=#{iterations} received=#{endpoint.received} " \
     "seconds=#{elapsed.round(6)} events_per_second=#{(iterations / elapsed).round(2)}"
agent.close(2.0)
endpoint.close
