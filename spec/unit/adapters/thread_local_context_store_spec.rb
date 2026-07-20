RSpec.describe Chronos::Adapters::ThreadLocalContextStore do
  it "restores nested context and clears it when a scope raises" do
    store = described_class.new

    expect do
      store.with_context(:request_id => "outer") do
        store.with_context(:user => "42") do
          expect(store.get).to eq(:request_id => "outer", :user => "42")
          raise "failed"
        end
      end
    end.to raise_error("failed")
    expect(store.get).to eq({})
  end

  it "does not share values between concurrent threads" do
    store = described_class.new
    ready = Queue.new
    release = Queue.new
    results = Queue.new

    threads = %w(one two).map do |value|
      Thread.new do
        store.with_context(:user => value) do
          ready << true
          release.pop
          results << store.get[:user]
        end
      end
    end
    2.times { ready.pop }
    2.times { release << true }
    threads.each(&:join)

    expect([results.pop, results.pop].sort).to eq(%w(one two))
    expect(store.get).to eq({})
  end
end
