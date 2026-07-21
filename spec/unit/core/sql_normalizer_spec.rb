RSpec.describe Chronos::Core::SqlNormalizer do
  it "removes comments and literal values while preserving operation and table" do
    normalizer = described_class.new
    first = normalizer.call(
      "SELECT users.* FROM users WHERE email = 'person@example.com' AND id = 42 -- private",
      :adapter => "PostgreSQL", :name => "User Load", :cached => false
    )
    second = normalizer.call(
      "select users.* from users where email = 'other@example.com' and id = 99",
      :adapter => "PostgreSQL", :name => "User Load", :cached => false
    )

    expect(first).to include(
      "operation" => "SELECT", "table" => "users", "adapter" => "PostgreSQL",
      "name" => "User Load", "cached" => false
    )
    expect(first["normalized_query"]).to eq("SELECT users.* FROM users WHERE email = ? AND id = ?")
    expect(first["fingerprint"]).to eq(second["fingerprint"])
    expect(first.to_s).not_to include("person@example.com", "private", "42")
  end

  it "bounds identifiers and extracts optional connection role and shard" do
    result = described_class.new.call(
      "UPDATE accounts SET active = true WHERE id IN (1, 2, 3)",
      :role => :writing, :shard => :default
    )

    expect(result).to include(
      "operation" => "UPDATE", "table" => "accounts",
      "role" => "writing", "shard" => "default"
    )
    expect(result["normalized_query"].bytesize).to be <= 512
  end
end
