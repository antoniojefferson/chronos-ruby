require "rbconfig"

RSpec.describe "public documentation" do
  it "documents public classes and required version 0.2 topics" do
    script = File.expand_path("../../script/verify_docs", __dir__)

    expect(system(RbConfig.ruby, script)).to eq(true)
  end
end
