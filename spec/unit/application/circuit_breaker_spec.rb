RSpec.describe Chronos::Application::CircuitBreaker do
  it "opens after the threshold and permits one probe after the reset timeout" do
    now = 10.0
    breaker = described_class.new(2, 5.0, proc { now })

    expect(breaker.allow_request?).to eq(true)
    breaker.record_failure
    breaker.record_failure
    expect(breaker.state).to eq(:open)
    expect(breaker.allow_request?).to eq(false)

    now = 15.0
    expect(breaker.allow_request?).to eq(true)
    expect(breaker.state).to eq(:half_open)
    expect(breaker.allow_request?).to eq(false)

    breaker.record_success
    expect(breaker.state).to eq(:closed)
  end
end
