require "chronos/rails/active_record_query_inspector"

RSpec.describe "SQL privacy boundaries" do
  def normalized(sql, adapter = "PostgreSQL")
    Chronos::Core::SqlNormalizer.new.call(sql, :adapter => adapter)
  end

  it "omits oversized SQL before it can leak an incomplete literal into an APM batch" do
    sql = "SELECT * FROM users WHERE value = 'private_literal_marker_#{'a' * 5000}'"
    data = normalized(sql).merge("duration_ms" => 1000)
    aggregator = Chronos::Application::ApmAggregator.new(snapshot)
    aggregator.record("query", data)
    bodies = aggregator.flush.map do |batch|
      event = Chronos::Core::TelemetryEvent.new("metric_batch", batch)
      Chronos::Core::TelemetrySerializer.new(snapshot).call(event).body
    end

    expect(data["operation"]).to eq("UNKNOWN")
    expect(bodies.join).not_to include("private_literal_marker", "aaaa")
  end

  it "fails closed on malformed, escaped or incomplete lexical input" do
    inputs = ["SELECT * FROM users WHERE value = 'private_marker",
              "SELECT $$private_marker", "SELECT $tag$private_marker",
              "SELECT /* private_marker", "SELECT 'a\\'private_marker'",
              "SELECT /*! private_marker */ 1", "SELECT /* nested /* comment */ 1"]
    inputs.each do |sql|
      result = normalized(sql)
      expect(result["operation"]).to eq("UNKNOWN")
      expect(result.to_s).not_to include("private_marker")
    end
  end

  it "masks complete quoted literals without treating their contents as comments" do
    ["SELECT 'a--private_marker' FROM users", "SELECT 'a/*private_marker*/b' FROM users",
     "SELECT $$private_marker$$ FROM users", "SELECT $tag$private_marker$tag$ FROM users",
     "SELECT 'a''private_marker' FROM users"].each do |sql|
      result = normalized(sql)
      expect(result["operation"]).to eq("SELECT")
      expect(result["normalized_query"]).to eq("SELECT ? FROM users")
    end
  end

  it "preserves PostgreSQL identifiers but masks ambiguous double-quoted strings" do
    expect(normalized('SELECT "id" FROM "users"')["table"]).to eq("users")
    ["Mysql2", ""].each do |adapter|
      result = normalized('SELECT "private_marker" FROM users', adapter)
      expect(result["normalized_query"]).to eq("SELECT ? FROM users")
    end
  end

  it "validates the whole original SQL before inspecting it regardless of supplied metadata" do
    connection = double("connection", :adapter_name => "PostgreSQL")
    metadata = {"operation" => "SELECT", "table" => "users", "normalized_query" => "SELECT * FROM users"}
    expect(connection).not_to receive(:indexes)
    expect(connection).not_to receive(:select_all)
    queries = ["SELECT * FROM users WHERE #{'id = 1 AND ' * 60}1=1; DELETE FROM users",
               "SELECT * FROM users WHERE value = '#{'a' * 5000}'",
               "SELECT * FROM users WHERE value = 'incomplete"]
    queries.each do |sql|
      result = Chronos::Rails::ActiveRecordQueryInspector.new.call(
        sql, metadata, :connection => connection, :plan => true, :statistics => true
      )
      expect(result).to eq({})
    end
  end

  it "allows a semicolon inside a complete literal but rejects a second statement" do
    expect(Chronos::Core::SqlLexer.new("SELECT 'a;b' FROM users;", "PostgreSQL").single_select?).to eq(true)
    expect(Chronos::Core::SqlLexer.new("SELECT 'a;b' FROM users; SELECT 2", "PostgreSQL").single_select?).to eq(false)
  end
end
