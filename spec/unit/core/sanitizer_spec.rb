RSpec.describe Chronos::Core::Sanitizer do
  def sanitizer(overrides = {})
    described_class.new(snapshot(overrides))
  end

  it "redacts blocked String, Symbol, and Regexp keys recursively" do
    value = {
      "password" => "plain-password",
      :api_key => "plain-api-key",
      "nested" => {"private-value" => "plain-private-value"}
    }
    result = sanitizer(:blocklist_keys => ["password", :api_key, /private-value/]).call(value)

    expect(result["password"]).to eq("[FILTERED]")
    expect(result[:api_key]).to eq("[FILTERED]")
    expect(result["nested"]["private-value"]).to eq("[FILTERED]")
  end

  it "keeps an explicitly allowlisted key while still filtering its contents" do
    result = sanitizer(
      :blocklist_keys => ["token"],
      :allowlist_keys => ["token"]
    ).call("token" => "Bearer secret-token")

    expect(result["token"]).to eq("Bearer [FILTERED]")
  end

  it "redacts common secrets and personal data embedded in strings" do
    value = [
      "Bearer secret-token",
      "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signature",
      "person@example.com",
      "529.982.247-25",
      "04.252.011/0001-10",
      "4111 1111 1111 1111"
    ]
    serialized = JSON.generate(sanitizer.call(value))

    value.each { |secret| expect(serialized).not_to include(secret) }
    expect(serialized).to include("[FILTERED_EMAIL]", "[FILTERED_DOCUMENT]", "[FILTERED_CARD]")
  end

  it "does not treat arbitrary operational numbers as CPF or CNPJ" do
    value = "thread 12345678901234 sequence 12345678901"

    expect(sanitizer.call(value)).to eq(value)
  end

  it "hashes configured identifiers irreversibly" do
    result = sanitizer(:hash_keys => ["customer_id"]).call("customer_id" => "customer-42")

    expect(result["customer_id"]).to match(/\A\[HASHED_SHA256:[0-9a-f]{64}\]\z/)
    expect(result["customer_id"]).not_to include("customer-42")
  end

  it "anonymizes IPv4 addresses by default and can be disabled" do
    expect(sanitizer.call("ip" => "request from 192.168.10.42")["ip"]).to eq("request from 192.168.10.0")
    expect(sanitizer(:anonymize_ip => false).call("ip" => "192.168.10.42")["ip"]).to eq("192.168.10.42")
  end

  it "applies custom filters without allowing failures to escape" do
    replacement = proc { |key, value| key.to_s == "internal" ? "[REMOVED]" : value }
    failing = proc { |_key, _value| raise "filter failed" }
    result = sanitizer(:filters => [replacement]).call("internal" => "debug")
    contained = sanitizer(:filters => [failing]).call("safe" => "value")

    expect(result["internal"]).to eq("[REMOVED]")
    expect(contained["safe"]).to eq("[FILTERED]")
  end

  it "bounds cycles, depth, collection sizes, and visited nodes" do
    cyclic = {}
    cyclic["self"] = cyclic
    oversized = Array.new(Chronos::Core::Sanitizer::MAX_ITEMS + 1, "value")

    expect(sanitizer.call(cyclic)["self"]).to eq("<circular reference>")
    expect(sanitizer.call(oversized).size).to eq(Chronos::Core::Sanitizer::MAX_ITEMS)
  end
end
