# Sidekiq 7 transitional integration

The historical integration began in `0.6.0.pre.1`. The current 1.2.2 line targets Sidekiq 7 through its public middleware APIs. Sidekiq 4/5 consumers must use a matching legacy release. Load the optional integration after declaring Sidekiq:

```ruby
gem "sidekiq", "~> 7.3"
gem "chronos-ruby", "~> 1.2.2", :require => "chronos/sidekiq"
```

`chronos/sidekiq` installs middleware through the public `configure_client` and `configure_server` APIs. It does nothing when Sidekiq is unavailable, and the core gem never requires Sidekiq. Installation adds no Chronos thread or Redis/database connection per job; delivery continues through the agent's existing fixed worker pool.

The client middleware adds a top-level `chronos` metadata object to the Sidekiq envelope. It never changes the public `args` array. Only bounded trace/span/request identifiers and flags propagate, with schema version and enqueue time. The server scopes that context for the worker, measures duration and calculable queue latency, and emits one `job` event.

Collected Sidekiq fields are worker class, queue, JID, retry count, duration, queue latency, status, error class, bounded tags, and bounded arguments. At most 20 top-level arguments, 20 values per nested collection, four levels, and 512 bytes per string are traversed. Arguments then pass through the standard sensitive-key/content sanitizer before queueing. Limits reduce exposure and resource use but do not make unnecessary personal data safe to collect.

On failure, the server middleware records a failed-job observation, invokes `notify_once`, and re-raises the identical exception so Sidekiq retains ownership of retries and failure handlers. A shared execution marker prevents a nested Active Job hook and the Sidekiq middleware from sending the same exception twice. Version 0.7 aggregates the job observation; the exception retains sanitized bounded arguments. Chronos does not install an additional global Sidekiq error handler.

## Validation scope

The pinned Sidekiq 7.3.10 fixture exercises actual middleware chains, argument preservation, context propagation, job telemetry and error re-raising across Ruby 2.7–3.4. It does not start Redis or a worker process. Redis-backed lifecycle evidence remains a separate promotion gate. See [Compatibility](../compatibility.md) and [1.2.2 readiness](../release-1.2.2-readiness.md).
