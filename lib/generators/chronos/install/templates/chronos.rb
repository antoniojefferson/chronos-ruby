require "chronos/rails"

# This initializer lists every public Chronos option so the application's
# monitoring behavior is explicit and can be reviewed in one place.
Chronos.configure do |config|
  # Identification and authentication

  # Identifies the project that will receive monitoring events.
  config.project_id = ENV["CHRONOS_PROJECT_ID"]
  # Authenticates event delivery. Keep this value in a secret manager.
  config.project_key = ENV["CHRONOS_PROJECT_KEY"]
  # Defines the Chronos Monitor endpoint used to deliver events.
  config.host = "https://chronosmonitor.com.br"
  # Labels events with the current Rails environment.
  config.environment = Rails.env.to_s
  # Identifies the deployed application version in events and releases.
  config.app_version = ENV["CHRONOS_APP_VERSION"]
  # Distinguishes this application from other monitored services.
  config.service_name = ENV["CHRONOS_SERVICE_NAME"]
  # Records the source revision, such as a Git commit SHA.
  config.revision = ENV["CHRONOS_REVISION"]
  # Associates events with a specific deployment.
  config.deploy_id = ENV["CHRONOS_DEPLOY_ID"]
  # Identifies the infrastructure region where the application is running.
  config.region = ENV["CHRONOS_REGION"]
  # Identifies the process, container, or host that produced an event.
  config.instance_id = ENV["CHRONOS_INSTANCE_ID"]
  # Removes the application root from file paths reported to Chronos.
  config.root_directory = Rails.root.to_s
  # Sends internal Chronos diagnostics through the Rails logger.
  config.logger = Rails.logger if Rails.respond_to?(:logger)

  # Transport and delivery

  # Limits how long an established request may wait for the Chronos server.
  config.timeout = 5
  # Limits how long Chronos may wait while opening a network connection.
  config.open_timeout = 2
  # Sets the maximum number of events waiting in the in-memory queue.
  config.queue_size = 100
  # Sets the number of background workers that deliver queued events.
  config.workers = 1
  # Enables or disables all Chronos event collection and delivery.
  config.enabled = true
  # Controls whether captured exceptions are sent to Chronos.
  config.error_notifications = true
  # Prevents delivery from the listed application environments.
  config.ignored_environments = []
  # Routes outbound requests through a proxy URL when one is required.
  config.proxy = nil
  # Verifies the TLS certificate presented by the Chronos endpoint.
  config.ssl_verify = true
  # Identifies this SDK in outbound HTTP requests.
  config.user_agent = "chronos-ruby/#{Chronos::VERSION}"
  # Rejects serialized events larger than this number of bytes.
  config.max_payload_size = 1_048_576
  # Compresses request payloads with gzip when enabled.
  config.gzip = false

  # Privacy and filtering

  # Removes values whose keys commonly contain credentials or private data.
  config.blocklist_keys = Chronos::Configuration::DEFAULT_BLOCKLIST_KEYS.dup
  # Keeps only the listed keys when this list is not empty.
  config.allowlist_keys = []
  # Applies custom callables that can transform or discard events.
  config.filters = []
  # Replaces values for these keys with stable hashes instead of raw data.
  config.hash_keys = []
  # Removes the final segment of captured IP addresses.
  config.anonymize_ip = true
  # Discards events that match any configured ignore rule.
  config.ignore_rules = []
  # Limits the number of ignore rules evaluated for each event.
  config.max_ignore_rules = 20

  # Reliability and remote configuration

  # Sets the number of delivery retries after a recoverable failure.
  config.max_retries = 3
  # Sets the initial delay, in seconds, for exponential retry backoff.
  config.retry_base_interval = 0.5
  # Caps the retry delay, in seconds.
  config.retry_max_interval = 30
  # Randomizes retry delays to prevent synchronized retry traffic.
  config.retry_jitter = 0.25
  # Keeps this many failed events in memory for later delivery attempts.
  config.backlog_size = 100
  # Opens the circuit breaker after this many consecutive failures.
  config.circuit_failure_threshold = 5
  # Waits this many seconds before testing an open circuit again.
  config.circuit_reset_timeout = 30
  # Allows the server to supply bounded runtime configuration updates.
  config.remote_configuration = true
  # Limits the size of an accepted remote configuration response, in bytes.
  config.remote_config_max_bytes = 4_096
  # Captures this fraction of eligible events, from 0.0 to 1.0.
  config.sampling_rate = 1.0
  # Restricts remote collection to these event categories.
  config.enabled_event_types = %w(
    exception request query job cache external_http dependencies deploy metric_batch
  )
  # Caps the server-requested interval between deliveries, in seconds.
  config.max_remote_send_interval = 60

  # Execution context and breadcrumbs

  # Isolates trace and request context between concurrent fibers.
  config.context_store = :fiber_local
  # Keeps this many recent breadcrumbs per execution context.
  config.breadcrumb_capacity = 20
  # Limits the serialized size of each breadcrumb, in bytes.
  config.breadcrumb_max_bytes = 2_048

  # Rails integration

  # Installs Rails request, job, cache, SQL, and error integrations.
  config.rails_enabled = true
  # Captures events from Rails console sessions when enabled.
  config.rails_capture_in_console = false
  # Captures events while the Rails test environment is running when enabled.
  config.rails_capture_in_test = false
  # Includes the request User-Agent in request metadata when enabled.
  config.rails_capture_user_agent = false

  # Application performance monitoring

  # Enables transaction, span, query, and aggregate performance monitoring.
  config.apm_enabled = true
  # Limits the number of metric groups retained between flushes.
  config.apm_max_groups = 200
  # Flushes APM aggregates after this many observations.
  config.apm_flush_count = 100
  # Sends at most this many APM items in one request.
  config.apm_batch_size = 50
  # Limits the SQL queries recorded for a single request or transaction.
  config.apm_max_queries_per_request = 100
  # Marks SQL queries slower than this duration, in milliseconds.
  config.apm_slow_query_threshold_ms = 500
  # Marks transactions longer than this duration, in milliseconds.
  config.apm_long_transaction_threshold_ms = 1_000
  # Reports repeated equivalent queries after this count is reached.
  config.apm_n_plus_one_threshold = 5
  # Defines the duration buckets, in milliseconds, used by APM histograms.
  config.apm_histogram_buckets = [5, 10, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000]
  # Retains active trace state for this many seconds.
  config.apm_trace_ttl_seconds = 60
  # Normalizes SQL and records bounded query analysis metadata.
  config.apm_query_analysis_enabled = true
  # Limits the number of analyzed queries retained per transaction.
  config.apm_query_analysis_max_queries = 100
  # Enables database-specific query inspection for slow queries.
  config.apm_query_inspection_enabled = false
  # Collects database query statistics when inspection supports them.
  config.apm_query_statistics_enabled = false
  # Collects query execution plans when inspection supports them.
  config.apm_query_plan_enabled = false
  # Inspects only queries at least this slow, in milliseconds.
  config.apm_query_inspection_min_duration_ms = 500
  # Limits the inspected queries retained per transaction.
  config.apm_query_inspection_max_queries = 20
  # Tracks database transaction lifecycles and durations.
  config.apm_transaction_tracking_enabled = true
  # Limits the database connections tracked for transaction state.
  config.apm_transaction_max_connections = 100

  # Distributed tracing and integrations

  # Instruments supported outbound HTTP clients when enabled.
  config.external_http_enabled = false
  # Propagates Chronos trace headers on instrumented outbound requests.
  config.external_http_trace_headers = true
  # Extracts and injects the standard W3C traceparent header when enabled.
  config.w3c_trace_context = false
  # Reuses an active OpenTelemetry span without configuring its SDK.
  config.opentelemetry_bridge = true
  # Controls cache key reporting; :none avoids collecting cache key material.
  config.cache_key_mode = :none
  # Reports a bounded inventory of application dependencies.
  config.dependency_reporting = true
  # Limits the number of dependencies included in an inventory event.
  config.dependency_max_items = 100
end

# Installation is idempotent, regardless of when the Railtie was evaluated.
Chronos::Rails::Installer.new.install(Rails.application)
