RSpec.describe Chronos::Integrations::OpenTelemetry do
  it "consumes valid identifiers from an already active span" do
    flags = double("flags", :sampled? => true)
    context = double("context", :valid? => true,
                     :hex_trace_id => "a" * 32, :hex_span_id => "b" * 16, :trace_flags => flags)
    span = double("span", :context => context)
    trace = Module.new
    trace.define_singleton_method(:current_span) { span }
    stub_const("OpenTelemetry", Module.new)
    stub_const("OpenTelemetry::Trace", trace)

    expect(described_class.current_context).to eq(
      "trace_id" => "a" * 32, "span_id" => "b" * 16,
      "trace_flags" => "01", "source" => "opentelemetry"
    )
  end
end
