require "minitest/autorun"
require "socket"
require "openssl"
require "tmpdir"
require "json"
require "zlib"
require "stringio"
require "open3"
require "rbconfig"
require_relative "support/deploy_tls_receiver"

# Real TLS ingestion fixture. It confirms the transport contract, not SaaS projection/ledger.
class DeployTransportTest < Minitest::Test
  def with_receiver(status)
    Dir.mktmpdir do |root|
      receiver = DeployTLSReceiver.new(root, status)
      begin
        yield receiver.url, receiver.ca_path, receiver.requests
      ensure
        receiver.stop
      end
    end
  end

  def notify(host, ca_path, policy = "fail", action = "notify")
    env = {"SSL_CERT_FILE" => ca_path, "CHRONOS_HOST" => host, "CHRONOS_PROJECT_ID" => "fixture",
           "CHRONOS_PROJECT_KEY" => "fixture-private-key", "CHRONOS_ENVIRONMENT" => "production",
           "CHRONOS_DEPLOY_ID" => "published-release-1", "CHRONOS_DEPLOY_REVISION" => "abc123",
           "DEPLOY_ENVIRONMENT" => nil, "DEPLOY_ID" => nil, "GIT_SHA" => nil, "APP_VERSION" => nil,
           "HTTP_PROXY" => nil, "HTTPS_PROXY" => nil, "http_proxy" => nil, "https_proxy" => nil}
    command = if ENV["CHRONOS_TEST_EXECUTABLE"]
                [ENV["CHRONOS_TEST_EXECUTABLE"]]
              else
                [RbConfig.ruby, "-Ilib", "exe/chronos"]
              end
    Open3.capture2e(env, *command, "deploy", action, "--json", "--timeout", "1", "--on-error", policy)
  end

  def test_confirmed_delivery_over_verified_tls
    with_receiver("202 Accepted") do |host, ca, requests|
      output, status = notify(host, ca)
      assert status.success?, output
      assert_equal true, JSON.parse(output)["success"]
      refute_includes output, "fixture-private-key"
      assert(requests.any? { |event| event.to_s.include?("published-release-1") })
    end
  end

  def test_permanent_and_retryable_failures_are_unconfirmed_without_blind_retries
    ["401 Unauthorized", "429 Too Many Requests", "503 Service Unavailable"].each do |response|
      with_receiver(response) do |host, ca, requests|
        output, status = notify(host, ca)
        assert_equal 2, status.exitstatus, output
        assert_equal "unconfirmed", JSON.parse(output)["state"]
        assert_equal(1, requests.count { |event| event["event_type"] == "deploy" })
        refute_includes output, "fixture-private-key"
      end
    end
  end

  def test_verify_requires_receipt_and_never_sends_deploy_or_dependencies
    [:receipt, "202 Accepted"].each do |response|
      with_receiver(response) do |host, ca, requests|
        output, status = notify(host, ca, "fail", "verify")
        assert_equal(response == :receipt ? 0 : 2, status.exitstatus, output)
        assert_equal(response == :receipt ? "verified" : "invalid_response", JSON.parse(output)["verification_status"])
        assert_equal(["exception"], requests.map { |event| event["event_type"] })
      end
    end
  end

  def test_timeout_is_unconfirmed
    with_receiver(:timeout) do |host, ca, _requests|
      output, status = notify(host, ca, "fail", "verify")
      assert_equal 2, status.exitstatus, output
      assert_equal false, JSON.parse(output)["success"]
    end
  end

  def test_repeated_publication_keeps_deploy_id_but_creates_another_event
    with_receiver("202 Accepted") do |host, ca, requests|
      2.times do
        output, status = notify(host, ca)
        assert status.success?, output
      end
      deploys = requests.select { |event| event["event_type"] == "deploy" }
      assert_equal 2, deploys.length
      assert_equal 2, deploys.map { |event| event["event_id"] }.uniq.length
      assert_equal ["published-release-1"], deploys.map { |event| event["payload"]["deploy_id"] }.uniq
    end
  end

  def test_untrusted_tls_does_not_deliver
    with_receiver("202 Accepted") do |host, _ca, requests|
      output, status = notify(host, "")
      assert_equal 2, status.exitstatus, output
      assert_empty requests
    end
  end
end
