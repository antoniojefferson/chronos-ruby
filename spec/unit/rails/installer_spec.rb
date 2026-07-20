require "chronos/rails"

RSpec.describe Chronos::Rails::Installer do
  class FakeMiddlewareStack
    attr_reader :entries

    def initialize
      @entries = []
    end

    def use(*arguments)
      @entries << arguments
    end
  end

  class FakeRailsNotifier
    def initialize(enabled = true)
      @enabled = enabled
    end

    def rails_integration_options(_environment, _console)
      {:enabled => @enabled, :include_user_agent => true}
    end
  end

  class FakeSubscriber
    attr_reader :installs

    def initialize
      @installs = 0
    end

    def install
      @installs += 1
      true
    end
  end

  def application
    middleware = FakeMiddlewareStack.new
    config = Struct.new(:middleware).new(middleware)
    [Struct.new(:config).new(config), middleware]
  end

  it "installs middleware and subscribers only once per application" do
    app, middleware = application
    subscriber = FakeSubscriber.new
    installer = described_class.new(FakeRailsNotifier.new, subscriber)

    expect(installer.install(app)).to eq(true)
    expect(installer.install(app)).to eq(false)
    expected = [
      [Chronos::Integrations::Rack::Middleware, {:include_user_agent => true}]
    ]
    expect(middleware.entries).to eq(expected)
    expect(subscriber.installs).to eq(1)
  end

  it "does not install when the configured environment disables Rails collection" do
    app, middleware = application
    installer = described_class.new(FakeRailsNotifier.new(false), FakeSubscriber.new)

    expect(installer.install(app)).to eq(false)
    expect(middleware.entries).to be_empty
  end
end
