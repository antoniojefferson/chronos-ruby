RSpec.describe Chronos::Application::RetryPolicy do
  it "uses bounded exponential backoff with deterministic jitter" do
    policy = described_class.new(
      :max_retries => 3,
      :base_interval => 1.0,
      :max_interval => 5.0,
      :jitter => 0.25,
      :random => proc { 1.0 }
    )

    expect(policy.delay(1)).to eq(1.25)
    expect(policy.delay(2)).to eq(2.5)
    expect(policy.delay(3)).to eq(5.0)
    expect(policy.retry?(Chronos::Ports::TransportResult.new(:server_error), 2)).to eq(true)
    expect(policy.retry?(Chronos::Ports::TransportResult.new(:server_error), 3)).to eq(false)
  end

  it "bounds Retry-After and rejects permanent client failures" do
    policy = described_class.new(:max_retries => 2, :base_interval => 1.0, :max_interval => 4.0, :jitter => 0.0)
    rate_limited = Chronos::Ports::TransportResult.new(:rate_limited, :retry_after => "30")
    client_error = Chronos::Ports::TransportResult.new(:client_error, :status_code => 400)

    expect(policy.delay(1, rate_limited)).to eq(4.0)
    expect(policy.retry?(client_error, 0)).to eq(false)
  end
end
