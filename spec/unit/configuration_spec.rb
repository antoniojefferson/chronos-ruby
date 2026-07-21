RSpec.describe Chronos::Configuration do # rubocop:disable Metrics/BlockLength
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
    expect(result.apm_enabled).to eq(true)
    expect(result.apm_max_groups).to eq(200)
    expect(result.apm_flush_count).to eq(100)
    expect(result.apm_max_queries_per_request).to eq(100)
    expect(result.external_http_enabled).to eq(false)
    expect(result.cache_key_mode).to eq(:none)
    expect(described_class.new.dependency_reporting).to eq(true)
    expect(result.dependency_reporting).to eq(false)
    expect(result.dependency_max_items).to eq(100)
    expect(result.blocklist_keys).to include("password", "authorization", "cpf", "cnpj")
    expect(result).to be_frozen
    expect(result.ignored_environments).to be_frozen
    expect(result.blocklist_keys).to be_frozen
  end

  it "validates HTTP, cache, and dependency collection settings" do
    config = configuration(
      :external_http_enabled => "yes", :cache_key_mode => :raw,
      :dependency_reporting => "yes", :dependency_max_items => 0
    )

    expect(config.validation_errors).to include(
      "external_http_enabled must be true or false",
      "cache_key_mode must be :none or :sha256",
      "dependency_reporting must be true or false",
      "dependency_max_items must be between 1 and 200"
    )
  end

  it "rejects unbounded APM aggregation and detector settings" do
    config = configuration(
      :apm_enabled => "yes", :apm_max_groups => 0, :apm_flush_count => 0,
      :apm_batch_size => 0, :apm_max_queries_per_request => 0,
      :apm_slow_query_threshold_ms => 0, :apm_n_plus_one_threshold => 1,
      :apm_histogram_buckets => [10.0, 5.0]
    )

    expect(config.validation_errors).to include(
      "apm_enabled must be true or false", "apm_max_groups must be a positive integer",
      "apm_flush_count must be a positive integer", "apm_batch_size must be between 1 and 50",
      "apm_max_queries_per_request must be a positive integer",
      "apm_slow_query_threshold_ms must be greater than zero",
      "apm_n_plus_one_threshold must be an integer greater than or equal to 2",
      "apm_histogram_buckets must contain increasing positive numbers"
    )
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
