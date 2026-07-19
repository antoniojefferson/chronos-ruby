RSpec.describe Chronos do
  it "has a version number" do
    expect(Chronos::VERSION).not_to be nil
  end

  it "defines a base error" do
    expect(Chronos::Error).to be < StandardError
  end
end
