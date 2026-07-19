RSpec.describe Chronos::Core::BacktraceParser do
  subject(:parser) { described_class.new("/srv/app") }

  it "parses CRuby frames and marks application files" do
    frame = parser.call(["/srv/app/services/pay.rb:42:in `call'"]).first

    expect(frame).to eq(
      "file" => "services/pay.rb",
      "line" => 42,
      "function" => "call",
      "in_app" => true
    )
  end

  it "preserves unknown frame formats without raising" do
    expect(parser.call(["org.jruby.SomeFrame(Unknown Source)"]).first["file"]).to include("jruby")
  end

  it "handles a missing backtrace" do
    expect(parser.call(nil)).to eq([])
  end
end
