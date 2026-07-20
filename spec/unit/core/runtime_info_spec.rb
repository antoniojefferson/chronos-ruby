RSpec.describe Chronos::Core::RuntimeInfo do
  it "uses an opaque non-decimal thread identifier" do
    info = described_class.new.call

    expect(info[:thread]["id"]).to match(/\A0x[0-9a-f]+\z/)
  end
end
