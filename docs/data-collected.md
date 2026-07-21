# Data collected

Version 0.8 emits exceptions, cache telemetry, one dependency inventory, and aggregated request/query/job/external-HTTP metric batches. All fields pass through the privacy sanitizer and bounded safe serializer before queueing, retry storage, or delivery.

| Data | Default | Source |
|---|---|---|
| Exception class and sanitized message | Collected | Ruby exception |
| Structured backtrace | Collected when present | Ruby exception |
| Sanitized cause class and message | Collected when present | `Exception#cause` |
| Ruby version, engine, platform | Collected | Ruby constants |
| PID and opaque thread ID | Collected | Ruby runtime |
| Hostname | Collected when available | Standard library |
| Environment and service | Configuration | Host application |
| Application version | Optional | Host application |
| Context, parameters, session, user | Optional and sanitized | Explicit capture arguments |
| Tags and fingerprint | Optional and sanitized | Explicit capture arguments |
| IPv4 address in supplied text | Anonymized | Explicit capture arguments |
| Rack method, normalized route, status, duration, request ID, host, query-free path, trace ID | Collected with Rack middleware | Rack environment and local clock |
| Rack user agent | Disabled by default | `HTTP_USER_AGENT` when middleware option is enabled |
| Rack controller/action | Collected when already supplied | Explicit Chronos or Action Dispatch environment values |
| Rack parameters | Collected only when already parsed | Explicit, Rack, or Action Dispatch parameter hashes |
| Response size | `Content-Length` when present | Rack response headers |
| Breadcrumbs | Explicit and bounded | Application and Chronos integration |
| Rails controller/action, status, method, query-free path, normalized route, duration | Collected with Rails integration | `process_action.action_controller` |
| Sanitized Rails parameters | Collected with Rails integration | Public controller notification payload |
| View template basename and duration | Collected with Rails integration | `render_template.action_view` |
| SQL operation name, cached flag, duration | Collected; SQL text omitted | `sql.active_record` |
| Mailer/action and duration | Collected; message content omitted | `deliver.action_mailer` |
| Active Job class, queue, duration | Collected when available; arguments omitted | `perform.active_job` |
| Sidekiq class, queue, JID, retry count, duration, status, error class | Collected with optional middleware | Sidekiq job envelope and local clock |
| Sidekiq queue latency | Collected when enqueue time is available | Sidekiq or Chronos envelope timestamp |
| Sidekiq arguments | Collected, sanitized, and bounded | First 20 job arguments; collections/depth/strings limited |
| Sidekiq tags | Collected and bounded | Job payload or public worker options |
| Sidekiq trace/request IDs | Propagated when present; trace generated otherwise | Chronos job-envelope metadata |
| APM counts, error counts/rates, duration total/min/max/average | Aggregated by default | Request, query, and job observations |
| Fixed duration histogram and status counts | Aggregated by default | Local bounded counters |
| Component breakdown | database/view/external_http/cache/queue/application when observable | Trace-local bounded totals |
| Normalized SQL and SHA-256 fingerprint | Collected without comments, literals, or binds | `sql.active_record` payload |
| SQL adapter, operation, inferred table, AR name, cache flag, role/shard | Collected when exposed | Public notification payload and connection feature detection |
| Slow SQL source frame | Collected only for threshold-selected slow queries | Bounded application call frame |
| APM diagnostic signals | Heuristic counters | Local threshold and repetition detection |
| External HTTP host, method, status, duration, timeout, connection-error flag, error class | Disabled by default; per-instance opt-in | Instrumented `Net::HTTP` object |
| Chronos trace/request headers | Propagated when available | Current execution context |
| Cache operation, backend, namespace, hit/miss, duration | Collected; key/value omitted | ActiveSupport cache notifications |
| Cache key hash | Disabled by default | Project-scoped SHA-256 when `cache_key_mode = :sha256` |
| Loaded gem names/versions and Ruby runtime | Once per agent by default; bounded | `Gem.loaded_specs` and Ruby constants |
| Rails, web server, database adapter, Sidekiq, release | Included when safely detectable/configured | Loaded constants/specs and `app_version` |

The gem never collects request bodies, response bodies, raw query strings, cookies, HTTP authorization headers, environment variables in bulk, source code, raw SQL, SQL bind values, database rows, raw cache keys/values, mail bodies/recipients, gem paths, or lockfile contents. Sidekiq JIDs/arguments and bounded loaded gem names/versions are documented integration fields.

APM dimensions never include user ID, job ID, raw URL, exception message, bind value, or cache key. Normalized routes replace common numeric/UUID segments. Normalized SQL can retain schema, table, and column identifiers; review those identifiers as part of the privacy audit.

The secret `project_key` is an authentication header and is excluded from the JSON payload and logger diagnostics. The envelope field named `project_key` contains the public `project_id` required by the current v1 server contract.

See [Privacy and LGPD](privacy-lgpd.md) for redaction rules and the payload audit procedure.
