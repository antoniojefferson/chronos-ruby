require "minitest/autorun"
require "stringio"
require "tmpdir"
require "open3"
require "rake"
require "chronos/rake_tasks"
require "chronos/deploy/installer"

class DeployAdaptersTest < Minitest::Test
  def test_rake_alias_is_idempotent_and_does_not_boot_environment
    previous = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task("environment") { raise "unexpected application boot" }
    output = StringIO.new
    exits = []
    options = {:output => output, :env => {}, :exit => proc { |code| exits << code }}
    Chronos::RakeTasks.install(options)
    Chronos::RakeTasks.install(options)
    task = Rake::Task["chronos:deploy"]
    assert_empty task.prerequisites
    assert_equal 1, task.actions.length
    task.invoke
    assert_equal [1], exits
    assert_equal false, JSON.parse(output.string)["success"]
  ensure
    Rake.application = previous
  end

  def test_templates_are_valid_shell_and_ruby_and_accept_roots_with_spaces
    Dir.mktmpdir("chronos espaço ") do |root|
      installer = Chronos::Deploy::Installer.new
      installer.install(:root => root, :provider => "kamal")
      output, status = Open3.capture2e("sh", "-n", File.join(root, ".kamal/hooks/post-deploy"))
      assert status.success?, output
      installer.install(:root => root, :provider => "capistrano")
      output, status = Open3.capture2e(RbConfig.ruby, "-c", File.join(root, "lib/capistrano/tasks/chronos_deploy.rake"))
      assert status.success?, output
    end
  end
end
