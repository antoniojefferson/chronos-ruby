#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "chronos/sidekiq"

# Minimal notifier used to demonstrate middleware without a Sidekiq process.
class ExampleNotifier
  def propagation_context
    {"trace_id" => "trace-example", "request_id" => "request-example"}
  end

  def with_context(_context)
    yield
  end

  def record_event(type, payload, _context = {})
    puts "#{type}: #{payload['class']} #{payload['status']} in #{payload['duration_ms']}ms"
  end

  def notify_once(error, _context = {})
    puts "exception: #{error.class}"
  end
end

notifier = ExampleNotifier.new
client = Chronos::Integrations::Sidekiq::ClientMiddleware.new(:notifier => notifier)
server = Chronos::Integrations::Sidekiq::ServerMiddleware.new(:notifier => notifier)
job = {"class" => "InvoiceWorker", "jid" => "example-1",
       "args" => [{"invoice_id" => "invoice-42", "password" => "do-not-log"}]}

client.call(Object, job, "billing", nil) { true }
server.call(Object.new, job, "billing") { true }
