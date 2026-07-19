# Data collected

Version 0.1 emits only manual exception events.

| Data | Default | Source |
|---|---|---|
| Exception class and message | Collected | Ruby exception |
| Structured backtrace | Collected when present | Ruby exception |
| Cause class and message | Collected when present | `Exception#cause` |
| Ruby version, engine, platform | Collected | Ruby constants |
| PID and opaque thread ID | Collected | Ruby runtime |
| Hostname | Collected when available | Standard library |
| Environment and service | Configuration | Host application |
| Application version | Optional | Host application |
| Context, parameters, session, user | Optional | Explicit capture arguments |
| Tags and fingerprint | Optional | Explicit capture arguments |

The gem never collects request bodies, response bodies, cookies, HTTP authorization headers, environment variables in bulk, source code, SQL bind values, database rows, or installed gems in version 0.1.

The secret `project_key` is an authentication header and is excluded from the JSON payload and logger diagnostics.
