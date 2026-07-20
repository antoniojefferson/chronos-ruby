require "chronos"

# In-memory output transport for the executable Rack example.
class ExampleTransport
  def send_event(event)
    puts event.body
    Chronos::Ports::TransportResult.new(:success, :status_code => 202)
  end

  def send_batch(events)
    events.map { |event| send_event(event) }
  end

  def healthy?
    true
  end

  def close
    true
  end
end

config = Chronos::Configuration.new
config.project_id = "local-rack-example"
config.project_key = "fixture-only"
config.host = "https://chronos.example.test"
agent = Chronos::Agent.new(config.snapshot, :transport => ExampleTransport.new)
app = proc { |_env| raise "example Rack failure" }
middleware = Chronos::Integrations::Rack::Middleware.new(app, :notifier => agent)

begin
  middleware.call(
    "REQUEST_METHOD" => "GET",
    "PATH_INFO" => "/accounts/42",
    "HTTP_HOST" => "example.test",
    "chronos.user" => {"id" => "example-user"}
  )
rescue RuntimeError => error
  puts "application still received: #{error.message}"
end

agent.flush(1.0)
agent.close(1.0)
