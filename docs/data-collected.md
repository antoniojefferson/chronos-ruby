# Data collected

Version 0.3 emits only manually submitted exception events. All fields pass through the privacy sanitizer and bounded safe serializer before queueing, retry storage, or delivery.

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

The gem never collects request bodies, response bodies, cookies, HTTP authorization headers, environment variables in bulk, source code, SQL bind values, database rows, or installed gems in version 0.3.

The secret `project_key` is an authentication header and is excluded from the JSON payload and logger diagnostics. The envelope field named `project_key` contains the public `project_id` required by the current v1 server contract.

See [Privacy and LGPD](privacy-lgpd.md) for redaction rules and the payload audit procedure.
