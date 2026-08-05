RSpec.describe Chronos::Core::SqlQueryAnalyzer do
  it "extracts bounded access columns and proposes an unverified index from normalized SQL" do
    result = described_class.new.call(
      "operation" => "SELECT", "table" => "payments",
      "normalized_query" => "SELECT * FROM payments WHERE account_id = ? AND status = ? ORDER BY created_at DESC"
    )

    expect(result["access_columns"]["payments"]).to eq(
      "equality" => %w(account_id status), "range" => [], "join" => [], "order" => ["created_at"]
    )
    expect(result["index_candidates"]).to include(
      include("table" => "payments", "columns" => %w(account_id status created_at),
              "status" => "unverified", "confidence" => "low")
    )
    expect(result["diagnostics"]).to include(include("code" => "index_candidate", "severity" => "suggestion"))
    expect(result["diagnostics"]).to include(include("code" => "query_pattern_analyzed", "severity" => "info"))
  end

  it "compares candidates with index metadata and reports plan warnings without retaining plan predicates" do
    query = {
      "operation" => "SELECT", "table" => "payments",
      "normalized_query" => "SELECT * FROM payments WHERE account_id = ? ORDER BY created_at DESC"
    }
    inspection = {
      "indexes" => [{"table" => "payments", "name" => "idx_payments_account_created",
                     "columns" => %w(account_id created_at), "unique" => false}],
      "statistics" => {"estimated_rows" => 50_000, "source" => "pg_class"},
      "plan" => {"nodes" => [{"type" => "Seq Scan", "table" => "payments",
                              "estimated_rows" => 12_000, "filter" => "token = raw-secret"}],
                 "uses_index" => false, "sequential_scan" => true}
    }

    result = described_class.new.call(query, inspection)

    expect(result["index_candidates"].first).to include(
      "status" => "covered", "covered_by" => "idx_payments_account_created", "confidence" => "high"
    )
    expect(result["diagnostics"]).to include(include("code" => "sequential_scan", "severity" => "warning"))
    expect(result.to_s).not_to include("raw-secret", "filter")
  end

  it "marks a candidate missing only after existing indexes are available" do
    result = described_class.new.call(
      {"operation" => "SELECT", "table" => "payments",
       "normalized_query" => "SELECT * FROM payments WHERE account_id = ? AND status = ?"},
      "indexes" => [{"table" => "payments", "name" => "idx_status", "columns" => ["status"]}]
    )

    expect(result["index_candidates"].first).to include("status" => "missing", "confidence" => "medium")
    expect(result["diagnostics"]).to include(
      include("code" => "missing_index_candidate", "severity" => "suggestion")
    )
  end

  it "does not recommend indexes for writes or malformed input" do
    result = described_class.new.call(
      "operation" => "UPDATE", "table" => "payments",
      "normalized_query" => "UPDATE payments SET status = ? WHERE id = ?"
    )

    expect(result["index_candidates"]).to eq([])
    expect(result["diagnostics"]).to eq([])
  end
end
