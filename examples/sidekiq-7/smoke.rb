require "sidekiq"
require "sidekiq/cli"
require "chronos"
require "chronos/integrations/sidekiq"
raise "expected Sidekiq 7" unless Sidekiq::VERSION.start_with?("7.")

# Tests real Sidekiq middleware chains without a Redis connection or running worker process.
class TransitionalNotifier
  attr_reader :events, :errors

  def initialize
    @events = []
    @errors = []
  end

  def propagation_context
    {"trace_id" => "synthetic-trace", "request_id" => "synthetic-request"}
  end

  def with_context(_context)
    yield
  end

  def record_event(type, payload)
    @events << [type, payload]
  end

  def notify_once(error, _context)
    @errors << error
    true
  end
end

notifier = TransitionalNotifier.new
config = Sidekiq.default_configuration
raise "middleware was not installed" unless Chronos::Integrations::Sidekiq.install(Sidekiq, notifier)
raise "duplicate installation" if Chronos::Integrations::Sidekiq.install(Sidekiq, notifier)
job = {"class" => "SyntheticWorker", "queue" => "default", "jid" => "synthetic-jid", "args" => ["unchanged"]}
original_args = job["args"].dup
config.client_middleware.invoke(Object, job, "default", nil) { true }
config.server_middleware.invoke(Object.new, job, "default") { true }
raise "arguments changed" unless job["args"] == original_args
raise "context missing" unless job["chronos"]
raise "job event missing or duplicated" unless notifier.events.count { |event| event.first == "job" } == 1
error = RuntimeError.new("synthetic worker failure")
raised = false
begin
  config.server_middleware.invoke(Object.new, job, "default") { raise error }
rescue RuntimeError => caught
  raised = true
  raise unless caught.equal?(error)
end
raise "failure was swallowed" unless raised
raise "failure not captured once" unless notifier.errors == [error]
puts "Sidekiq #{Sidekiq::VERSION} / Ruby #{RUBY_VERSION} middleware smoke passed (Redis not exercised)"
