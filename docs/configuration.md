# Configuration

`Chronos.configure` creates a mutable configuration, validates it, and gives runtime components an immutable snapshot.

| Option | Required | Default | Description |
|---|---:|---|---|
| `project_id` | Yes when enabled | `nil` | Public project identifier included in the envelope |
| `project_key` | Yes when enabled | `nil` | Secret authentication key sent only as an HTTP header |
| `host` | Yes when enabled | `nil` | Absolute Chronos HTTP endpoint; HTTPS is required by default |
| `environment` | Recommended | `production` | Application environment |
| `app_version` | Optional | `nil` | Application release/version identifier |
| `service_name` | Recommended | `nil` | Logical service name |
| `revision` | Optional | `nil` | Source revision correlated with every event; maximum 128 bytes |
| `deploy_id` | Optional | `nil` | Deployment identifier correlated with every event; maximum 128 bytes |
| `region` | Optional | `nil` | Deployment region correlated with every event; maximum 128 bytes |
| `instance_id` | Optional | `nil` | Explicit instance correlation; otherwise runtime hostname is used |
| `root_directory` | Optional | `Dir.pwd` | Used to identify application backtrace frames |
| `logger` | Optional | `nil` | Logger receiving bounded internal diagnostics |
| `timeout` | Optional | `5.0` | HTTP read timeout in seconds |
| `open_timeout` | Optional | `2.0` | HTTP connection timeout in seconds |
| `queue_size` | Optional | `100` | Maximum queued events |
| `workers` | Optional | `1` | Fixed positive worker count |
| `enabled` | Optional | `true` | Enables all capture |
| `error_notifications` | Optional | `true` | Enables exception events |
| `ignored_environments` | Optional | `[]` | Environments where capture is disabled |
| `proxy` | Optional | `nil` | Absolute HTTP proxy URL |
| `ssl_verify` | Recommended | `true` | Enables TLS peer verification |
| `user_agent` | Optional | Agent version | HTTP user agent |
| `max_payload_size` | Optional | `1048576` | Maximum serialized payload bytes |
| `gzip` | Optional | `false` | Compresses request bodies with gzip |
| `blocklist_keys` | Recommended | Sensitive-key defaults | String, Symbol, or Regexp keys whose values are redacted |
| `allowlist_keys` | Optional | `[]` | Explicit key-name exceptions; content detection still runs |
| `hash_keys` | Optional | `[]` | Scalar identifier keys replaced by scoped SHA-256 values |
| `filters` | Optional | `[]` | Callable application-specific privacy filters |
| `anonymize_ip` | Recommended | `true` | Replaces the final octet of supplied IPv4 addresses |
| `max_retries` | Optional | `3` | Maximum retry attempts after the first delivery failure |
| `retry_base_interval` | Optional | `0.5` | Initial exponential-backoff delay in seconds |
| `retry_max_interval` | Optional | `30.0` | Maximum local or `Retry-After` delay in seconds |
| `retry_jitter` | Optional | `0.25` | Random positive jitter fraction between `0.0` and `1.0` |
| `backlog_size` | Optional | `100` | Maximum sanitized events retained in memory after delivery failure; `0` disables retention |
| `circuit_failure_threshold` | Optional | `5` | Consecutive retryable failures before opening the circuit |
| `circuit_reset_timeout` | Optional | `30.0` | Seconds before one half-open delivery probe |
| `remote_configuration` | Optional | `true` | Accepts only the documented bounded remote policy fields |
| `remote_config_max_bytes` | Optional | `4096` | Maximum remote policy response-header bytes |
| `sampling_rate` | Optional | `1.0` | Local upper bound for event sampling |
| `enabled_event_types` | Optional | exception, request, query, job, cache, external_http, dependencies, deploy, metric_batch | Local allowlist for supported event envelopes |
| `max_remote_send_interval` | Optional | `60.0` | Local upper bound for remotely requested send spacing |
| `context_store` | Optional | `:thread_local` | `:thread_local` or an object implementing `get`, `set`, `clear`, and `with_context` |
| `breadcrumb_capacity` | Optional | `20` | Positive count of newest breadcrumbs retained per execution |
| `breadcrumb_max_bytes` | Optional | `2048` | Maximum bytes per normalized breadcrumb; minimum `128` |
| `rails_enabled` | Optional | `true` | Enables automatic Rails middleware and subscribers |
| `rails_capture_in_console` | Optional | `false` | Enables automatic integration while Rails console is loaded |
| `rails_capture_in_test` | Optional | `false` | Enables automatic integration in the Rails test environment |
| `rails_capture_user_agent` | Optional | `false` | Adds the Rack user agent to request context |
| `apm_enabled` | Optional | `true` | Aggregates request, query, job, and enabled external HTTP observations into bounded metric batches |
| `apm_max_groups` | Optional | `200` | Maximum metric groups and active trace trackers retained locally |
| `apm_flush_count` | Optional | `100` | Aggregate observations accepted before a threshold drain |
| `apm_batch_size` | Optional | `50` | Metric groups per batch; hard maximum 50 |
| `apm_max_queries_per_request` | Optional | `100` | Query fingerprints tracked per trace for repetition signals |
| `apm_slow_query_threshold_ms` | Optional | `500.0` | Query duration that produces a slow-query signal and sampled source |
| `apm_long_transaction_threshold_ms` | Optional | `1000.0` | Transaction-labelled SQL duration that produces a signal |
| `apm_n_plus_one_threshold` | Optional | `5` | Repeated fingerprint count producing one possible-N+1 signal; minimum 2 |
| `apm_histogram_buckets` | Optional | Fixed millisecond boundaries | Increasing positive duration boundaries; at most 19 plus `+Inf` |
| `external_http_enabled` | Optional | `false` | Allows explicit per-instance outbound `Net::HTTP` instrumentation |
| `external_http_trace_headers` | Optional | `true` | Propagates Chronos trace/request headers on instrumented requests |
| `cache_key_mode` | Optional | `:none` | `:none` omits keys; `:sha256` emits a project-scoped key hash |
| `dependency_reporting` | Optional | `true` | Emits one bounded dependency event per configured agent |
| `dependency_max_items` | Optional | `100` | Loaded gem entries retained in the inventory; range 1–200 |

```ruby
Chronos.configure do |config|
  config.project_id = ENV["CHRONOS_PROJECT_ID"]
  config.project_key = ENV["CHRONOS_PROJECT_KEY"]
  config.host = ENV["CHRONOS_HOST"]
  config.environment = ENV["APP_ENV"] || "production"
  config.service_name = "billing"
  config.app_version = ENV["APP_VERSION"]
  config.revision = ENV["GIT_SHA"]
  config.deploy_id = ENV["DEPLOY_ID"]
  config.region = ENV["REGION"]
  config.instance_id = ENV["INSTANCE_ID"]
  config.queue_size = 100
  config.workers = 1
  config.blocklist_keys += [:medical_record, /bank_account/i]
  config.hash_keys += [:customer_id]
  config.max_retries = 3
  config.backlog_size = 100
  config.circuit_failure_threshold = 5
  config.context_store = :thread_local
  config.breadcrumb_capacity = 20
  config.rails_capture_in_test = false
  config.rails_capture_in_console = false
  config.apm_enabled = true
  config.apm_max_groups = 200
  config.apm_flush_count = 100
  config.apm_batch_size = 50
  config.apm_max_queries_per_request = 100
  config.apm_slow_query_threshold_ms = 500.0
  config.apm_long_transaction_threshold_ms = 1000.0
  config.apm_n_plus_one_threshold = 5
  config.external_http_enabled = false
  config.external_http_trace_headers = true
  config.cache_key_mode = :none
  config.dependency_reporting = true
  config.dependency_max_items = 100
end
```

Privacy matcher collections and filters are copied into the immutable runtime snapshot. Matchers must be String, Symbol, or Regexp values, and every custom filter must respond to `call`.

The gem never reads all environment variables automatically. The host application decides which values to pass. See [Privacy and LGPD](privacy-lgpd.md) before adding application context.

Remote configuration can only reduce collection within local bounds. It cannot increase `max_payload_size` or `sampling_rate`, enable an unsupported or locally disabled event type, change the endpoint, replace credentials, disable TLS verification, or install executable matching rules.

Release correlation values are copied into the immutable snapshot. Calling `Chronos.notify_deploy` reports a deployment but does not mutate those values for concurrent application events; configure each deployed process with its own release identity.
