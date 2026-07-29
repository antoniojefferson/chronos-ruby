require "rbconfig"

RSpec.describe "public documentation" do
  it "documents public classes and required stable 1.0 topics" do
    script = File.expand_path("../../script/verify_docs", __dir__)

    expect(system(RbConfig.ruby, script)).to eq(true)
  end

  it "documents every public configuration option" do
    path = File.expand_path("../../docs/configuration.md", __dir__)
    documentation = File.open(path, "r:UTF-8", &:read)

    Chronos::Configuration::ATTRIBUTES.each do |attribute|
      expect(documentation).to include("`#{attribute}`")
    end
  end
end
