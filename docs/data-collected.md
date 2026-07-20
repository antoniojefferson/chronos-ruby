# Data collected

Version 0.5 emits exception, request, query, job, and cache events. All fields pass through the privacy sanitizer and bounded safe serializer before queueing, retry storage, or delivery.

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
| Cache operation, store, hit flag, duration | Collected; key/value omitted | ActiveSupport cache notifications |

The gem never collects request bodies, response bodies, raw query strings, cookies, HTTP authorization headers, environment variables in bulk, source code, raw SQL, SQL bind values, database rows, cache keys/values, mail bodies/recipients, job IDs/arguments, or installed gems in version 0.5.

The secret `project_key` is an authentication header and is excluded from the JSON payload and logger diagnostics. The envelope field named `project_key` contains the public `project_id` required by the current v1 server contract.

See [Privacy and LGPD](privacy-lgpd.md) for redaction rules and the payload audit procedure.
