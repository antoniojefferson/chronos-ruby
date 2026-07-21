# Migration from Airbrake

Version `0.9.0.pre.2` provides a staged migration path. Run both agents only long enough to compare delivery, then remove Airbrake to avoid duplicate reports and overhead.

| Airbrake concept | Chronos equivalent |
|---|---|
| `Airbrake.configure` credentials/host | `Chronos.configure` with `project_id`, `project_key`, and `host` |
| `Airbrake.notify(error, params)` | `Chronos.notify(error, :parameters => params)` |
| `Airbrake.notify_sync` | `Chronos.notify_sync` |
| ignore/filter callbacks | `Chronos.ignore_if` and `config.filters` |
| deploy notification | `Chronos.notify_deploy` |
| Rack/Rails integration | `require "chronos/rails"` or Chronos Rack middleware |

Start with `error_notifications`, Rails capture, and APM enabled in one non-production environment. Configure the same application version and environment used by the old notifier. Compare exception count, class, sanitized context, deploy correlation, request/job metrics, and retry diagnostics. Never copy an Airbrake project key into Chronos.

Chronos callbacks receive a normalized immutable `Chronos::Core::Notice`, not an Airbrake notice. Filters operate on each sanitized key/value pair. Translate callback logic explicitly and add tests; do not assume callback argument compatibility. Chronos intentionally omits request/response bodies, raw SQL, binds, cookies, authorization headers, mail content, and raw cache keys.

Before removing Airbrake, exercise a synchronous notification, an asynchronous notification followed by `Chronos.flush`, a Rails/Rack failure, a background job failure, and an unavailable endpoint. Confirm that the bounded queue/backlog behavior is acceptable. Roll back by disabling Chronos or restoring the previous dependency; no application exception semantics are changed by the agent.
