RSpec.describe Chronos::Application::ApmAggregator do # rubocop:disable Metrics/BlockLength
  def aggregator(overrides = {})
    described_class.new(snapshot(overrides))
  end

  it "aggregates request counts, errors, duration, histograms, and breakdown" do
    subject = aggregator
    payload = {
      "route" => "/accounts/:id", "method" => "GET", "status" => 200,
      "duration_ms" => 100.0, "breakdown_ms" => {"database" => 25.0, "view" => 10.0}
    }
    subject.record("request", payload, "trace_id" => "trace-1")
    subject.record("request", payload.merge("status" => 500, "duration_ms" => 200.0),
                   "trace_id" => "trace-2")

    batch = subject.flush.first
    metric = batch.fetch("metrics").first
    expect(metric).to include("metric_type" => "request", "count" => 2, "error_count" => 1)
    expect(metric["error_rate"]).to eq(0.5)
    expect(metric["duration_ms"]).to eq(
      "total" => 300.0, "min" => 100.0, "max" => 200.0, "average" => 150.0
    )
    expect(metric["percentiles_ms"]).to include("p50" => 100.0, "p95" => 250.0, "p99" => 250.0)
    histogram_count = metric["histogram"].inject(0) { |total, bucket| total + bucket["count"] }
    expect(histogram_count).to eq(2)
    expect(metric["breakdown_ms"]).to include("database" => 50.0, "view" => 20.0)
  end

  it "uses complete transaction duration and classifies bounded database error families" do
    subject = aggregator(:apm_long_transaction_threshold_ms => 1000.0)
    subject.record(
      "query", "operation" => "COMMIT", "fingerprint" => "transaction", "duration_ms" => 2.0,
               "transaction_duration_ms" => 1500.0, "error_class" => "ActiveRecord::LockWaitTimeout"
    )

    metric = subject.flush.first["metrics"].first
    expect(metric["signals"]).to include("long_transaction" => 1, "query_timeout" => 1, "lock_timeout" => 1)
    expect(metric["diagnostics"]).to include(
      include("code" => "long_transaction", "severity" => "warning"),
      include("code" => "lock_timeout", "severity" => "error")
    )
  end

  it "detects bounded slow, repeated, and possible N+1 query signals per request" do
    subject = aggregator(:apm_n_plus_one_threshold => 3, :apm_slow_query_threshold_ms => 50.0)
    query = {
      "operation" => "SELECT", "table" => "accounts", "fingerprint" => "fingerprint-1",
      "normalized_query" => "SELECT * FROM accounts WHERE id = ?", "duration_ms" => 75.0
    }
    4.times { subject.record("query", query, "trace_id" => "trace-1") }
    subject.record(
      "request", {"route" => "/accounts", "method" => "GET", "status" => 200, "duration_ms" => 400.0},
      "trace_id" => "trace-1"
    )

    metrics = subject.flush.first.fetch("metrics")
    request = metrics.find { |metric| metric["metric_type"] == "request" }
    query_metric = metrics.find { |metric| metric["metric_type"] == "query" }
    expect(request["breakdown_ms"]["database"]).to eq(300.0)
    expect(request["signals"]).to include(
      "slow_query" => 4, "repeated_query" => 3, "possible_n_plus_one" => 1
    )
    expect(query_metric["count"]).to eq(4)
  end

  it "bounds metric groups and per-request query fingerprints" do
    subject = aggregator(:apm_max_groups => 1, :apm_max_queries_per_request => 1)
    subject.record("query", {"fingerprint" => "one", "duration_ms" => 1.0}, "trace_id" => "trace")
    subject.record("query", {"fingerprint" => "two", "duration_ms" => 1.0}, "trace_id" => "trace")

    expect(subject.diagnostics).to include("groups" => 1, "dropped_groups" => 1)
    expect(subject.diagnostics["tracked_queries"]).to eq(1)
  end

  it "emits long transaction, connection, and deadlock signals from bounded metadata" do
    subject = aggregator(:apm_long_transaction_threshold_ms => 1000.0)
    subject.record(
      "query",
      "operation" => "BEGIN", "name" => "TRANSACTION", "fingerprint" => "transaction",
      "duration_ms" => 1500.0, "error_class" => "ActiveRecord::Deadlocked"
    )
    subject.record(
      "query",
      "operation" => "SELECT", "fingerprint" => "connection", "duration_ms" => 1.0,
      "error_class" => "ActiveRecord::ConnectionNotEstablished"
    )

    metrics = subject.flush.first.fetch("metrics")
    signals = metrics.each_with_object({}) do |metric, result|
      metric["signals"].each { |name, count| result[name] = result.fetch(name, 0) + count }
    end
    expect(signals).to include("long_transaction" => 1, "deadlock" => 1, "connection_error" => 1)
  end

  it "attaches errors, warnings, infos, and suggestions to query metrics" do
    subject = aggregator(:apm_n_plus_one_threshold => 2, :apm_slow_query_threshold_ms => 50.0)
    query = {
      "operation" => "SELECT", "fingerprint" => "payments", "duration_ms" => 75.0,
      "error_class" => "ActiveRecord::Deadlocked",
      "analysis" => {
        "tables" => ["payments"],
        "diagnostics" => [{"code" => "missing_index_candidate", "severity" => "suggestion",
                           "category" => "index", "message" => "Review index",
                           "evidence" => {"table" => "payments", "columns" => ["account_id"]}}]
      }
    }
    2.times { subject.record("query", query, "trace_id" => "trace") }

    metric = subject.flush.first["metrics"].find { |item| item["metric_type"] == "query" }
    expect(metric["severity_counts"]).to include("error" => 4, "warning" => 3, "info" => 1, "suggestion" => 3)
    expect(metric["diagnostics"]).to include(
      include("code" => "query_execution_error", "severity" => "error"),
      include("code" => "deadlock", "severity" => "error"),
      include("code" => "possible_n_plus_one", "severity" => "warning"),
      include("code" => "n_plus_one_eager_loading", "severity" => "suggestion"),
      include("code" => "missing_index_candidate", "severity" => "suggestion")
    )
    expect(metric["query_analysis"]).to include("tables" => ["payments"])
    expect(metric["query_analysis"]).not_to have_key("diagnostics")
  end

  it "preserves bounded trace correlation across aggregate flushes" do
    clock = 0.0
    subject = described_class.new(
      snapshot(:apm_n_plus_one_threshold => 3, :apm_trace_ttl_seconds => 60.0),
      :clock => proc { clock }
    )
    query = {"operation" => "SELECT", "fingerprint" => "accounts", "duration_ms" => 10.0}
    2.times { subject.record("query", query, "trace_id" => "trace") }
    first = subject.flush.first
    expect(first["metrics"].first["tracking"]["active_traces"]).to eq(1)

    subject.record("query", query, "trace_id" => "trace")
    subject.record("request", {"route" => "/accounts", "method" => "GET", "duration_ms" => 50.0},
                   "trace_id" => "trace")
    request = subject.flush.first["metrics"].find { |item| item["metric_type"] == "request" }

    expect(request["signals"]).to include("repeated_query" => 2, "possible_n_plus_one" => 1)
    expect(subject.diagnostics["transactions"]).to eq(0)
  end

  it "expires stale traces and reports bounded tracking loss" do
    clock = 0.0
    subject = described_class.new(snapshot(:apm_trace_ttl_seconds => 10.0), :clock => proc { clock })
    subject.record("query", {"operation" => "SELECT", "fingerprint" => "old", "duration_ms" => 1.0},
                   "trace_id" => "trace")
    subject.flush
    clock = 11.0
    subject.record("query", "operation" => "SELECT", "fingerprint" => "new", "duration_ms" => 1.0)

    batch = subject.flush.first
    expect(batch["metrics"].first["tracking"]).to include("expired_trace_trackers" => 1, "active_traces" => 0)
  end
end
