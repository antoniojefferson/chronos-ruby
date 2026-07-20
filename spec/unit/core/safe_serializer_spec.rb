RSpec.describe Chronos::Core::SafeSerializer do
  class UnsafeSerializableObject
    def to_json(*)
      raise "must not be called"
    end

    def to_s
      raise "must not be called"
    end
  end

  subject(:serializer) { described_class.new }

  it "normalizes only JSON primitives without invoking application serialization" do
    result = serializer.call("object" => UnsafeSerializableObject.new)

    expect(result).to eq("object" => "<UnsafeSerializableObject>")
  end

  it "contains circular structures and excessive depth" do
    value = {}
    value["self"] = value

    expect(serializer.call(value)["self"]).to eq("<circular reference>")
    expect(serializer.call({"a" => {"b" => {"c" => "value"}}}, :max_depth => 2)).to include("a")
  end

  it "bounds strings, hashes, arrays, and total visited nodes" do
    serializer = described_class.new(
      :max_string_bytes => 8,
      :max_keys => 2,
      :max_items => 2,
      :max_nodes => 5
    )
    result = serializer.call(
      "string" => "abcdefghijklmnop",
      "array" => [1, 2, 3],
      "ignored" => "value"
    )

    expect(result.keys.size).to eq(2)
    expect(result["string"].bytesize).to be <= 11
    expect(result["array"]).to eq([1, 2])
  end

  it "repairs invalid UTF-8" do
    invalid = "message".dup
    invalid.force_encoding("UTF-8")
    invalid.setbyte(0, 255)

    expect { JSON.generate(serializer.call("message" => invalid)) }.not_to raise_error
  end
end
