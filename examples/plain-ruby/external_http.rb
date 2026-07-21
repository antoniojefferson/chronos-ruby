#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "chronos/net_http"

# Collects synthetic telemetry without network delivery.
class ExampleHttpNotifier
  attr_reader :events

  def initialize
    @events = []
  end

  def external_http_integration_options
    {:enabled => true, :trace_headers => true}
  end

  def propagation_context
    {"trace_id" => "trace-example", "request_id" => "request-example"}
  end

  def record_event(type, payload, _context = {})
    @events << [type, payload]
    true
  end
end

# Small Net::HTTP-compatible request fixture.
class ExampleHttpRequest
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

# Small Net::HTTP-compatible connection fixture.
class ExampleHttpConnection
  attr_reader :address

  def initialize
    @address = "payments.example.test"
  end

  def request(_request, _body = nil)
    Struct.new(:code).new("204")
  end
end

notifier = ExampleHttpNotifier.new
connection = ExampleHttpConnection.new
Chronos::Integrations::NetHttp.install(connection, :notifier => notifier)
connection.request(ExampleHttpRequest.new)
puts notifier.events.inspect
