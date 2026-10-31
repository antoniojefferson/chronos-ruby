require "minitest/autorun"
require "stringio"
require "tmpdir"
require "chronos/cli"

class DeployCLITest < Minitest::Test
  def run_cli(args, env = {})
    output = StringIO.new
    code = Chronos::CLI.new(output, env).run(args)
    [code, output.string]
  end

  def test_local_commands_do_not_load_agent
    assert_equal 0, run_cli(["--help"])[0]
    assert_equal 1, run_cli(%w(deploy diagnose --offline))[0]
  end

  def test_secret_arguments_are_not_reflected
    code, output = run_cli(%w(deploy notify --project-key supersecret))
    assert_equal 1, code
    refute_includes output, "supersecret"
  end

  def test_conflicting_aliases_are_rejected
    result = run_cli(%w(deploy diagnose --offline), "CHRONOS_ENVIRONMENT" => "a", "DEPLOY_ENVIRONMENT" => "b")
    assert_equal 1, result[0]
  end

  def test_notify_requires_stable_identity_even_in_warn_mode
    env = {"CHRONOS_PROJECT_ID" => "p", "CHRONOS_PROJECT_KEY" => "secret", "CHRONOS_ENVIRONMENT" => "production"}
    code, output = run_cli(%w(deploy notify --on-error=warn), env)
    assert_equal 1, code
    refute_includes output, "secret"
  end

  def test_installation_is_idempotent_and_conflicts_are_preserved
    Dir.mktmpdir do |root|
      args = ["deploy", "install", "--provider", "kamal", "--root", root]
      assert_equal 0, run_cli(args + ["--dry-run"])[0]
      path = File.join(root, ".kamal/hooks/post-deploy")
      refute File.exist?(path)
      assert_equal 0, run_cli(args)[0]
      assert_equal 0, run_cli(args + ["--check"])[0]
      File.write(path, "customer hook")
      assert_equal 1, run_cli(args)[0]
      assert_equal "customer hook", File.read(path)
    end
  end

  def test_symlink_is_rejected_even_with_force
    Dir.mktmpdir do |root|
      Dir.mktmpdir do |outside|
        File.symlink(outside, File.join(root, ".kamal"))
        assert_equal 1, run_cli(["deploy", "install", "--provider", "kamal", "--root", root, "--force"])[0]
        assert_empty Dir.entries(outside) - %w(. ..)
      end
    end
  end

  def test_complete_offline_configuration_does_not_load_runner_in_fresh_process
    require "open3"
    script = <<-'RUBY'
    require "chronos/cli"
    code = Chronos::CLI.new.run(%w(deploy diagnose --offline))
    abort "agent loaded" if defined?(Chronos::Agent)
    exit code
    RUBY
    env = {"CHRONOS_PROJECT_ID" => "p", "CHRONOS_PROJECT_KEY" => "private", "CHRONOS_ENVIRONMENT" => "production",
           "CHRONOS_DEPLOY_ID" => "release-1", "CHRONOS_DEPLOY_REVISION" => "abc"}
    output, status = Open3.capture2e(env, RbConfig.ruby, "-Ilib", "-e", script)
    assert status.success?, output
    refute_includes output, "private"
  end

  def test_invalid_hosts_and_timeouts_remain_configuration_errors
    ["http://example.com", "https://user:private@example.com", "https://bad host",
     "https://example.com/?token=private"].each do |host|
      code, output = run_cli(["deploy", "diagnose", "--offline", "--host", host])
      assert_equal 1, code
      refute_includes output, "private"
    end
    %w(0 -1 61 NaN Infinity).each do |value|
      assert_equal 1, run_cli(["deploy", "notify", "--timeout", value])[0]
    end
  end

  def test_options_are_not_silently_ignored
    assert_equal 1, run_cli(%w(deploy notify --dry-run))[0]
    assert_equal 1, run_cli(%w(deploy verify --provider kamal))[0]
    assert_equal 1, run_cli(%w(deploy install --provider kamal --force --check))[0]
  end

  def test_conflict_preview_never_discloses_existing_content
    Dir.mktmpdir do |root|
      path = File.join(root, ".kamal/hooks/post-deploy")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "customer-secret")
      args = ["deploy", "install", "--provider", "kamal", "--root", root]
      code, output = run_cli(args + ["--dry-run"])
      assert_equal 1, code
      assert_includes JSON.parse(output)["diff"], "+++ proposed"
      refute_includes output, "customer-secret"
      assert_equal "customer-secret", File.read(path)
      assert_equal 0, run_cli(args + ["--force"])[0]
      assert File.executable?(path)
    end
  end

  def test_yaml_objects_aliases_and_unknown_fields_are_rejected
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "config"))
      ["--- !ruby/object:Object {}", "environment: &env production\nversion: *env", "actor: private",
       "version: 12"].each do |source|
        File.write(File.join(root, "config/chronos-deploy.yml"), source)
        assert_equal 1, run_cli(["deploy", "diagnose", "--offline", "--root", root])[0]
      end
    end
  end

  def test_all_templates_generate
    Chronos::Deploy::Installer::PATHS.each do |provider, path|
      Dir.mktmpdir do |root|
        assert_equal 0, run_cli(["deploy", "install", "--provider", provider, "--root", root])[0]
        content = File.read(File.join(root, path))
        assert_includes content, "chronos"
        YAML.safe_load(content) if path.end_with?(".yml")
      end
    end
  end
end

class DeployRunnerTest < Minitest::Test
  def stub_method(target, name, replacement)
    original = target.method(name)
    target.define_singleton_method(name) do |*args, &block|
      replacement.respond_to?(:call) ? replacement.call(*args, &block) : replacement
    end
    yield
  ensure
    target.define_singleton_method(name, original)
  end

  def test_delivery_and_close_share_existing_facade
    require "chronos/deploy/runner"
    values = {"project_id" => "p", "project_key" => "secret", "environment" => "production",
              "deploy_id" => "release-1", "revision" => "abc"}
    closed = []
    stub_method(Chronos, :configure, proc { |&block| block.call(Chronos::Configuration.new) }) do
      stub_method(Chronos, :notify_deploy, false) do
        stub_method(Chronos, :close, proc { |timeout| closed << timeout }) do
          assert_equal false, Chronos::Deploy::Runner.new.call("notify", values, 2)
        end
      end
    end
    assert_equal [2], closed
  end

  def test_warn_preserves_unconfirmed_json
    require "chronos/deploy/runner"
    env = {"CHRONOS_PROJECT_ID" => "p", "CHRONOS_PROJECT_KEY" => "secret", "CHRONOS_ENVIRONMENT" => "production",
           "CHRONOS_DEPLOY_ID" => "release-1", "CHRONOS_DEPLOY_REVISION" => "abc"}
    runner = Chronos::Deploy::Runner.new
    output = StringIO.new
    stub_method(runner, :call, false) do
      stub_method(Chronos::Deploy::Runner, :new, proc { runner }) do
        assert_equal 0, Chronos::CLI.new(output, env).run(%w(deploy notify --on-error=warn))
      end
    end
    assert_equal false, JSON.parse(output.string)["success"]
    refute_includes output.string, "secret"
  end

  def test_close_failure_prevents_confirmed_notify
    require "chronos/deploy/runner"
    values = {"project_id" => "p", "project_key" => "secret", "environment" => "production",
              "deploy_id" => "release-1", "revision" => "abc"}
    stub_method(Chronos, :configure, proc {}) do
      stub_method(Chronos, :notify_deploy, true) do
        stub_method(Chronos, :close, false) do
          assert_equal false, Chronos::Deploy::Runner.new.call("notify", values, 1)
        end
      end
    end
  end

  def test_internal_failure_still_closes_and_does_not_print_exception
    require "chronos/deploy/runner"
    env = {"CHRONOS_PROJECT_ID" => "p", "CHRONOS_PROJECT_KEY" => "secret", "CHRONOS_ENVIRONMENT" => "production",
           "CHRONOS_DEPLOY_ID" => "release-1", "CHRONOS_DEPLOY_REVISION" => "abc"}
    closed = []
    output = StringIO.new
    stub_method(Chronos, :configure, proc { raise "private-exception-message" }) do
      stub_method(Chronos, :close, proc { |timeout| closed << timeout }) do
        assert_equal 3, Chronos::CLI.new(output, env).run(%w(deploy notify))
      end
    end
    assert_equal [5.0], closed
    refute_includes output.string, "private-exception-message"
  end

  def test_public_yaml_and_secret_rejection
    Dir.mktmpdir do |root|
      Dir.mkdir(File.join(root, "config"))
      path = File.join(root, "config/chronos-deploy.yml")
      File.write(path, "environment: production\n")
      assert_equal "production", Chronos::Deploy::Configuration.read({:root => root}, {})["environment"]
      File.write(path, "project_key: secret\n")
      assert_raises(ArgumentError) { Chronos::Deploy::Configuration.read({:root => root}, {}) }
    end
  end
end
