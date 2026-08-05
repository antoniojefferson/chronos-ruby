#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "chronos"

normalizer = Chronos::Core::SqlNormalizer.new
analyzer = Chronos::Core::SqlQueryAnalyzer.new
query = normalizer.call(
  "SELECT * FROM payments WHERE account_id = 42 AND status = 'pending' ORDER BY created_at DESC",
  :adapter => "PostgreSQL", :name => "Payment Load"
)
inspection = {
  "indexes" => [
    {"table" => "payments", "name" => "index_payments_on_account_id",
     "columns" => ["account_id"], "unique" => false}
  ],
  "statistics" => {"estimated_rows" => 50_000, "source" => "pg_class"},
  "plan" => {
    "nodes" => [{"type" => "Seq Scan", "table" => "payments", "estimated_rows" => 12_000}],
    "uses_index" => false, "sequential_scan" => true
  }
}

puts analyzer.call(query, inspection).inspect
