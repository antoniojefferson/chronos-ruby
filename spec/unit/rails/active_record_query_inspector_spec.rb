require "chronos/rails"

RSpec.describe Chronos::Rails::ActiveRecordQueryInspector do # rubocop:disable Metrics/BlockLength
  Index = Struct.new(:name, :columns, :unique)

  class InspectionConnection
    attr_reader :queries

    def initialize
      @queries = []
    end

    def adapter_name
      "PostgreSQL"
    end

    def indexes(_table)
      [Index.new("idx_payments_account", ["account_id"], false)]
    end

    def quote(value)
      "'#{value}'"
    end

    def select_all(sql)
      @queries << sql
      return [{"estimated_rows" => 15_000}] if sql.include?("pg_class")

      [{"QUERY PLAN" => '[{"Plan":{"Node Type":"Index Scan","Relation Name":"payments",' \
                          '"Index Name":"idx_payments_account","Plan Rows":4,"Total Cost":8.5,' \
                          '"Filter":"token = raw-secret"}}]'}]
    end
  end

  class MysqlInspectionConnection < InspectionConnection
    def adapter_name
      "Mysql2"
    end

    def select_all(sql)
      @queries << sql
      return [{"estimated_rows" => 20_000}] if sql.include?("information_schema")

      [{"select_type" => "SIMPLE", "table" => "payments", "type" => "ref",
        "key" => "idx_payments_account", "rows" => 5, "Extra" => "raw planner text"}]
    end
  end

  it "collects allowlisted index, statistics, and non-executing plan evidence" do
    connection = InspectionConnection.new
    result = described_class.new.call(
      "SELECT * FROM payments WHERE account_id = 42",
      {"operation" => "SELECT", "table" => "payments",
       "normalized_query" => "SELECT * FROM payments WHERE account_id = ?"},
      :connection => connection, :statistics => true, :plan => true
    )

    expect(result["indexes"]).to eq(
      [{"table" => "payments", "name" => "idx_payments_account",
        "columns" => ["account_id"], "unique" => false}]
    )
    expect(result["statistics"]).to eq("estimated_rows" => 15_000, "source" => "pg_class")
    expect(result["plan"]).to include("uses_index" => true, "sequential_scan" => false)
    expect(result["plan"]["nodes"].first).to include(
      "type" => "Index Scan", "table" => "payments", "index" => "idx_payments_account"
    )
    expect(result.to_s).not_to include("raw-secret", "Filter")
    expect(connection.queries.grep(/EXPLAIN ANALYZE/)).to be_empty
  end

  it "rejects writes, multi-statements, and missing connections" do
    connection = InspectionConnection.new
    expect(described_class.new.call(
             "DELETE FROM payments", {"operation" => "DELETE", "table" => "payments"},
             :connection => connection, :plan => true
    )).to eq({})
    expect(described_class.new.call(
             "SELECT * FROM payments; DELETE FROM users",
             {"operation" => "SELECT", "table" => "payments",
              "normalized_query" => "SELECT * FROM payments; DELETE FROM users"},
             :connection => connection, :plan => true
    )).to eq({})
    expect(connection.queries).to be_empty
  end

  it "allowlists MySQL statistics and tabular plan fields" do
    connection = MysqlInspectionConnection.new
    result = described_class.new.call(
      "SELECT * FROM payments WHERE account_id = 42",
      {"operation" => "SELECT", "table" => "payments",
       "normalized_query" => "SELECT * FROM payments WHERE account_id = ?"},
      :connection => connection, :statistics => true, :plan => true
    )

    expect(result["statistics"]).to eq("estimated_rows" => 20_000, "source" => "information_schema")
    expect(result["plan"]).to include("uses_index" => true, "sequential_scan" => false)
    expect(result.to_s).not_to include("raw planner text", "Extra")
  end

  it "contains inspection failures as error-class evidence" do
    connection = InspectionConnection.new
    allow(connection).to receive(:indexes).and_raise(RuntimeError, "private detail")

    result = described_class.new.call(
      "SELECT * FROM payments", {"operation" => "SELECT", "table" => "payments",
                                 "normalized_query" => "SELECT * FROM payments"},
      :connection => connection
    )

    expect(result).to eq("errors" => ["RuntimeError"])
    expect(result.to_s).not_to include("private detail")
  end
end
