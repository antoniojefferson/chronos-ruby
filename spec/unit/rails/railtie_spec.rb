require "chronos/rails"
require "chronos/rake_tasks"

RSpec.describe "Chronos Rails Railtie" do
  it "registers installation after application configuration without Zeitwerk" do
    railtie_base = Class.new do
      class << self
        attr_reader :initializer_name, :initializer_options, :initializer_block, :rake_tasks_block

        def initializer(name, options = {}, &block)
          @initializer_name = name
          @initializer_options = options
          @initializer_block = block
        end

        def rake_tasks(&block)
          @rake_tasks_block = block
        end
      end
    end
    rails = Module.new
    rails.const_set(:Railtie, railtie_base)
    stub_const("Rails", rails)
    path = File.expand_path("../../../lib/chronos/rails/railtie.rb", __dir__)

    load path

    expect(Chronos::Rails::Railtie.superclass).to equal(railtie_base)
    expect(Chronos::Rails::Railtie.initializer_name).to eq("chronos.install")
    expect(Chronos::Rails::Railtie.initializer_options).to eq(:after => :load_config_initializers)
    expect(Chronos::Rails::Railtie.rake_tasks_block).to be_a(Proc)
  end

  it "requires the Rails environment even when its Rake task is defined later" do
    allow(Chronos::RakeTasks).to receive(:install)

    Chronos::Rails::Railtie.rake_tasks_block.call

    expect(Chronos::RakeTasks).to have_received(:install).with(:load_environment => true)
  end

  it "is discovered automatically when Rails is already loaded" do
    script = <<-RUBY
      module Rails
        class Railtie
          def self.initializer(*_arguments); end
          def self.rake_tasks; end
        end
      end
      require "chronos"
      abort "missing automatic railtie" unless defined?(Chronos::Rails::Railtie)
    RUBY

    expect(system(RbConfig.ruby, "-Ilib", "-e", script)).to eq(true)
  end
end
