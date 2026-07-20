RSpec.describe Chronos::Configuration do
  it "builds an immutable snapshot with legacy-safe defaults" do
    result = snapshot

    expect(result.queue_size).to eq(100)
    expect(result.workers).to eq(1)
    expect(result.ssl_verify).to eq(true)
    expect(result.gzip).to eq(false)
    expect(result.anonymize_ip).to eq(true)
    expect(result.max_retries).to eq(3)
    expect(result.backlog_size).to eq(100)
    expect(result.circuit_failure_threshold).to eq(5)
    expect(result.remote_configuration).to eq(true)
    expect(result.sampling_rate).to eq(1.0)
    expect(result.context_store).to eq(:thread_local)
    expect(result.breadcrumb_capacity).to eq(20)
    expect(result.blocklist_keys).to include("password", "authorization", "cpf", "cnpj")
    expect(result).to be_frozen
    expect(result.ignored_environments).to be_frozen
    expect(result.blocklist_keys).to be_frozen
  end

  it "rejects unbounded resilience and remote configuration settings" do
    config = configuration(
      :max_retries => -1,
      :retry_base_interval => 5.0,
      :retry_max_interval => 1.0,
      :retry_jitter => 2.0,
      :backlog_size => -1,
      :circuit_failure_threshold => 0,
      :remote_configuration => "yes",
      :sampling_rate => 1.5,
      :enabled_event_types => [:exception]
    )

    expect(config.validation_errors).to include("max_retries must be a non-negative integer")
    expect(config.validation_errors).to include(
      "retry_max_interval must be greater than or equal to retry_base_interval"
    )
    expect(config.validation_errors).to include("retry_jitter must be between zero and one")
    expect(config.validation_errors).to include("backlog_size must be a non-negative integer")
    expect(config.validation_errors).to include("circuit_failure_threshold must be a positive integer")
    expect(config.validation_errors).to include("remote_configuration must be true or false")
    expect(config.validation_errors).to include("sampling_rate must be between zero and one")
    expect(config.validation_errors).to include("enabled_event_types must contain only String values")
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

  it "validates privacy configuration" do
    config = configuration(
      :blocklist_keys => "password",
      :allowlist_keys => nil,
      :hash_keys => ["id"],
      :filters => [Object.new],
      :anonymize_ip => "yes"
    )

    expect(config.validation_errors).to include("blocklist_keys must be an array")
    expect(config.validation_errors).to include("allowlist_keys must be an array")
    expect(config.validation_errors).to include("filters must contain only callable objects")
    expect(config.validation_errors).to include("anonymize_ip must be true or false")
  end

  it "freezes the filter collection without freezing application callables" do
    filter = proc { |_key, value| value }
    result = snapshot(:filters => [filter])

    expect(result.filters).to be_frozen
    expect(filter).not_to be_frozen
  end
end
