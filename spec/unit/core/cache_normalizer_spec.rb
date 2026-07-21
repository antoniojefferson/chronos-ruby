RSpec.describe Chronos::Core::CacheNormalizer do
  it "omits cache keys by default while retaining bounded operational metadata" do
    normalizer = described_class.new("project-id", :none)
    result = normalizer.call(
      "cache_read.active_support",
      :key => "customer:42:secret", :store => "RedisCacheStore", :namespace => "billing", :hit => false
    )

    expect(result).to include(
      "operation" => "cache_read", "backend" => "RedisCacheStore",
      "namespace" => "billing", "hit" => false, "outcome" => "miss"
    )
    expect(result).not_to have_key("key_hash")
    expect(result.to_s).not_to include("customer", "secret")
  end

  it "creates a project-scoped SHA-256 key only when explicitly enabled" do
    first = described_class.new("project-one", :sha256).call(
      "cache_read.active_support", :key => "account:42", :options => {:namespace => "accounts"}
    )
    second = described_class.new("project-two", :sha256).call("cache_read.active_support", :key => "account:42")

    expect(first["key_hash"]).to match(/\A[0-9a-f]{64}\z/)
    expect(first["key_hash"]).not_to eq(second["key_hash"])
    expect(first["namespace"]).to eq("accounts")
    expect(first.to_s).not_to include("account:42")
  end
end
