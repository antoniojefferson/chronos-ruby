require "sidekiq"
require "chronos/sidekiq"

expected_major = ENV.fetch("EXPECTED_SIDEKIQ_MAJOR", "4")
raise "expected Sidekiq #{expected_major}" unless Sidekiq::VERSION.start_with?("#{expected_major}.")

# Minimal notifier used to exercise real Sidekiq middleware signatures.
class SmokeNotifier
  attr_reader :events

  def initialize
    @events = []
  end

  def propagation_context
    {"trace_id" => "trace-sidekiq"}
  end

  def with_context(_context)
    yield
  end

  def record_event(type, payload)
    @events << [type, payload]
  end

  def notify_once(_error, _context)
    true
  end
end

notifier = SmokeNotifier.new
job = {"class" => "DiagnosticWorker", "queue" => "default", "jid" => "jid-1", "args" => ["safe"]}
Chronos::Integrations::Sidekiq::ClientMiddleware.new(:notifier => notifier).call(Object, job, "default") { true }
Chronos::Integrations::Sidekiq::ServerMiddleware.new(:notifier => notifier).call(Object.new, job, "default") { true }

raise "context was not propagated" unless job["chronos"]
raise "job event was not recorded" unless notifier.events.first.first == "job"
puts "Sidekiq #{Sidekiq::VERSION} smoke passed"
