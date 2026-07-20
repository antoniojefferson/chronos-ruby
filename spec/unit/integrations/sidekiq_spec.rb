require "chronos/sidekiq"

RSpec.describe Chronos::Integrations::Sidekiq do
  class SidekiqRecordingNotifier
    attr_reader :events, :exceptions, :scopes

    def initialize
      @events = []
      @exceptions = []
      @scopes = []
    end

    def propagation_context
      {"trace_id" => "trace-1", "request_id" => "request-1", "secret" => "excluded"}
    end

    def with_context(context)
      @scopes << context
      yield
    end

    def record_event(type, payload, context = {})
      @events << [type, payload, context]
      true
    end

    def notify_once(exception, context = {})
      @exceptions << [exception, context]
      true
    end
  end

  class SidekiqWorker
    def self.get_sidekiq_options # rubocop:disable Style/AccessorMethodName
      {"queue" => "critical", "tags" => ["billing"]}
    end
  end

  it "propagates an allowlisted context without changing public job arguments" do
    notifier = SidekiqRecordingNotifier.new
    middleware = described_class::ClientMiddleware.new(:notifier => notifier, :clock => proc { 100.0 })
    job = {"args" => ["customer", {"password" => "secret"}]}
    original_arguments = Marshal.load(Marshal.dump(job["args"]))

    yielded = middleware.call(SidekiqWorker, job, "critical", nil) { :accepted }

    expect(yielded).to eq(:accepted)
    expect(job["args"]).to eq(original_arguments)
    expect(job["chronos"]).to eq(
      "schema_version" => "1.0", "enqueued_at" => 100.0,
      "context" => {"trace_id" => "trace-1", "request_id" => "request-1"}
    )
  end

  it "records bounded successful job telemetry and queue latency" do
    notifier = SidekiqRecordingNotifier.new
    ticks = [5.0, 5.025]
    middleware = described_class::ServerMiddleware.new(
      :notifier => notifier, :clock => proc { ticks.shift }, :wall_clock => proc { 101.0 }
    )
    job = {
      "class" => "SidekiqWorker", "queue" => "critical", "jid" => "jid-1",
      "retry_count" => 2, "enqueued_at" => 100.5,
      "args" => (1..25).map { |number| "argument-#{number}" },
      "chronos" => {"context" => {"trace_id" => "trace-1"}}
    }

    expect(middleware.call(SidekiqWorker.new, job, "critical") { :done }).to eq(:done)

    payload = notifier.events.first[1]
    expect(payload).to include(
      "kind" => "sidekiq", "class" => "SidekiqWorker", "queue" => "critical",
      "jid" => "jid-1", "retry_count" => 2, "duration_ms" => 25.0,
      "queue_latency_ms" => 500.0, "status" => "completed", "tags" => ["billing"]
    )
    expect(payload["arguments"].length).to eq(20)
    expect(payload["arguments_truncated"]).to eq(true)
    expect(notifier.scopes.first[:__chronos_captured_exceptions]).to eq({})
  end

  it "notifies a failed job once and re-raises the same exception" do
    notifier = SidekiqRecordingNotifier.new
    ticks = [1.0, 1.01]
    middleware = described_class::ServerMiddleware.new(
      :notifier => notifier, :clock => proc { ticks.shift }, :wall_clock => proc { 2.0 }
    )
    error = RuntimeError.new("failed")

    expect do
      middleware.call(SidekiqWorker.new, {"jid" => "jid-2", "args" => []}, "default") { raise error }
    end.to raise_error(RuntimeError) { |raised| expect(raised).to equal(error) }

    expect(notifier.exceptions.map(&:first)).to eq([error])
    expect(notifier.events.length).to eq(1)
    expect(notifier.events.first[1]).to include("status" => "failed", "error_class" => "RuntimeError")
  end
end
