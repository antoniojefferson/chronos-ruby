# Configuration

`Chronos.configure` creates a mutable configuration, validates it, and gives runtime components an immutable snapshot.

| Option | Required | Default | Description |
|---|---:|---|---|
| `project_id` | Yes when enabled | `nil` | Public project identifier included in the envelope |
| `project_key` | Yes when enabled | `nil` | Secret authentication key sent only as an HTTP header |
| `host` | Yes when enabled | `nil` | Absolute Chronos HTTP endpoint; HTTPS is required by default |
| `environment` | Recommended | `production` | Application environment |
| `app_version` | Optional | `nil` | Release or revision identifier |
| `service_name` | Recommended | `nil` | Logical service name |
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
| `sampling_rate` | Optional | `1.0` | Local upper bound for exception sampling |
| `enabled_event_types` | Optional | `["exception"]` | Local event-type allowlist; only exception exists in version 0.3 |
| `max_remote_send_interval` | Optional | `60.0` | Local upper bound for remotely requested send spacing |

```ruby
Chronos.configure do |config|
  config.project_id = ENV["CHRONOS_PROJECT_ID"]
  config.project_key = ENV["CHRONOS_PROJECT_KEY"]
  config.host = ENV["CHRONOS_HOST"]
  config.environment = ENV["APP_ENV"] || "production"
  config.service_name = "billing"
  config.queue_size = 100
  config.workers = 1
  config.blocklist_keys += [:medical_record, /bank_account/i]
  config.hash_keys += [:customer_id]
  config.max_retries = 3
  config.backlog_size = 100
  config.circuit_failure_threshold = 5
end
```

Privacy matcher collections and filters are copied into the immutable runtime snapshot. Matchers must be String, Symbol, or Regexp values, and every custom filter must respond to `call`.

The gem never reads all environment variables automatically. The host application decides which values to pass. See [Privacy and LGPD](privacy-lgpd.md) before adding application context.

Remote configuration can only reduce collection within local bounds. It cannot increase `max_payload_size` or `sampling_rate`, enable an unsupported or locally disabled event type, change the endpoint, replace credentials, disable TLS verification, or install executable matching rules.
