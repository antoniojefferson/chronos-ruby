RSpec.describe Chronos::Configuration do
  it "builds an immutable snapshot with legacy-safe defaults" do
    result = snapshot

    expect(result.queue_size).to eq(100)
    expect(result.workers).to eq(1)
    expect(result.ssl_verify).to eq(true)
    expect(result.gzip).to eq(false)
    expect(result).to be_frozen
    expect(result.ignored_environments).to be_frozen
  end

  it "requires credentials and an HTTPS host when enabled" do
    config = described_class.new

    expect { config.snapshot }.to raise_error(Chronos::ConfigurationError, /project_id is required/)
  end

  it "allows explicit HTTP only when TLS verification is disabled" do
    config = configuration(:host => "http://127.0.0.1:9292", :ssl_verify => false)

    expect(config.snapshot.host).to eq("http://127.0.0.1:9292")
  end

  it "rejects unbounded or invalid worker and queue settings" do
    config = configuration(:queue_size => 0, :workers => -1)

    expect(config.validation_errors).to include("queue_size must be a positive integer")
    expect(config.validation_errors).to include("workers must be a positive integer")
  end

  it "can be disabled without credentials" do
    config = described_class.new
    config.enabled = false

    expect(config.snapshot.enabled_for_environment?).to eq(false)
  end
end
