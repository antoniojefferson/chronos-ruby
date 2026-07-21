require "chronos/capistrano"

RSpec.describe Chronos::Integrations::Capistrano do
  class FakeCapistranoDsl
    attr_reader :tasks, :hooks

    def initialize(values)
      @values = values
      @tasks = {}
      @hooks = []
    end

    def namespace(_name)
      yield
    end

    def desc(_text); end

    def task(name, &block)
      @tasks[name.to_s] = block
    end

    def after(source, target)
      @hooks << [source, target]
    end

    def fetch(name, default = nil)
      @values.fetch(name, default)
    end
  end

  it "registers an after-published task with bounded deploy fields" do
    dsl = FakeCapistranoDsl.new(
      :stage => :production, :current_revision => "abc123", :chronos_version => "1.2.3",
      :repo_url => "owner/repository", :chronos_actor => "release-bot"
    )
    allow(Chronos).to receive(:notify_deploy).and_return(true)

    expect(described_class.install(dsl)).to eq(true)
    expect(dsl.hooks).to include(["deploy:published", "chronos:notify_deploy"])
    expect(dsl.tasks.fetch("notify_deploy").call).to eq(true)
    expect(Chronos).to have_received(:notify_deploy).with(
      a_hash_including(
        :environment => "production", :revision => "abc123", :version => "1.2.3",
        :repository => "owner/repository", :actor => "release-bot"
      )
    )
  end

  it "does not register twice on the same DSL" do
    dsl = FakeCapistranoDsl.new({})

    expect(described_class.install(dsl)).to eq(true)
    expect(described_class.install(dsl)).to eq(false)
  end
end
