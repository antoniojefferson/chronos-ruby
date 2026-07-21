RSpec.describe Chronos::Application::ApmAggregator do
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
    histogram_count = metric["histogram"].inject(0) { |total, bucket| total + bucket["count"] }
    expect(histogram_count).to eq(2)
    expect(metric["breakdown_ms"]).to include("database" => 50.0, "view" => 20.0)
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
end
