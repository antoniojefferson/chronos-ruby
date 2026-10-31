require "rake"
require "stringio"
require "chronos/rake_tasks"
require "chronos/cli"

RSpec.describe "Chronos deploy Rake task" do
  around do |example|
    previous = Rake.application
    Rake.application = Rake::Application.new
    begin
      example.run
    ensure
      Rake.application = previous
    end
  end

  [0, 2].each do |status|
    it "delegates once to the CLI and preserves exit status #{status} without booting Rails" do
      output = StringIO.new
      env = {"CHRONOS_DEPLOY_ID" => "release-1"}
      exits = []
      cli = instance_double(Chronos::CLI)
      allow(Chronos::CLI).to receive(:new).with(output, env).and_return(cli)
      expect(cli).to receive(:run).with(["deploy", "notify"]).once.and_return(status)
      Rake::Task.define_task("environment") { raise "unexpected application boot" }

      options = {:output => output, :env => env, :exit => proc { |code| exits << code }}
      expect(Chronos::RakeTasks.install(options)).to eq(true)
      expect(Chronos::RakeTasks.install).to eq(false)
      task = Rake::Task["chronos:deploy"]
      expect(task.prerequisites).to eq([])
      expect(task.actions.length).to eq(1)
      task.invoke

      expect(exits).to eq(status.zero? ? [] : [status])
    end
  end

  it "preserves a deploy task already registered by the application" do
    calls = []
    Rake::Task.define_task("chronos:deploy") { calls << :application }
    expect(Chronos::CLI).not_to receive(:new)

    Chronos::RakeTasks.install
    Rake::Task["chronos:deploy"].invoke

    expect(calls).to eq([:application])
    expect(Rake::Task["chronos:deploy"].actions.length).to eq(1)
  end

  it "registers deploy even when verification is already registered" do
    Rake::Task.define_task(Chronos::RakeTasks::TASK_NAME)

    expect(Chronos::RakeTasks.install).to eq(false)

    expect(Rake::Task.task_defined?("chronos:deploy")).to eq(true)
    expect(Rake::Task[Chronos::RakeTasks::TASK_NAME].actions).to eq([])
  end
end
