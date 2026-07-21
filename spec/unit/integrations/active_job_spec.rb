require "chronos/rails"

RSpec.describe Chronos::Integrations::ActiveJob do
  class ActiveJobNotifier
    attr_reader :scopes

    def initialize
      @scopes = []
    end

    def propagation_context
      {"trace_id" => "trace-1", "request_id" => "request-1", "secret" => "excluded"}
    end

    def with_context(context)
      @scopes << context
      yield
    end
  end

  def active_job_base
    Class.new do
      attr_reader :deserialized

      def serialize(*_arguments)
        {"job_class" => "DiagnosticJob", "arguments" => ["public-argument"]}
      end

      def deserialize(data)
        @deserialized = data
        self
      end

      def perform_now
        "performed"
      end
    end
  end

  it "propagates bounded context without changing public job arguments" do
    notifier = ActiveJobNotifier.new
    base = active_job_base

    expect(described_class.install(base, notifier)).to eq(true)
    expect(described_class.install(base, notifier)).to eq(false)
    serialized = base.new.serialize
    restored = base.new
    restored.deserialize(serialized)

    expect(serialized["arguments"]).to eq(["public-argument"])
    expect(serialized.fetch("chronos_context")).to eq(
      "schema_version" => "1.0",
      "context" => {"trace_id" => "trace-1", "request_id" => "request-1"}
    )
    expect(restored.perform_now).to eq("performed")
    expect(notifier.scopes).to eq([:context => {"trace_id" => "trace-1", "request_id" => "request-1"}])
  end
end
