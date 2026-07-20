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
end
```

Privacy matcher collections and filters are copied into the immutable runtime snapshot. Matchers must be String, Symbol, or Regexp values, and every custom filter must respond to `call`.

The gem never reads all environment variables automatically. The host application decides which values to pass. See [Privacy and LGPD](privacy-lgpd.md) before adding application context.
