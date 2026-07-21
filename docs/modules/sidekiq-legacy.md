# Sidekiq 4/5 legacy integration

Version `0.6.0.pre.1` starts the legacy jobs line with optional Sidekiq 4 and 5 client and server middleware. Load it after declaring Sidekiq:

```ruby
gem "sidekiq", "~> 5.0"
gem "chronos-ruby", "0.9.0.pre.1", :require => "chronos/sidekiq"
```

`chronos/sidekiq` installs middleware through the public `configure_client` and `configure_server` APIs. It does nothing when Sidekiq is unavailable, and the core gem never requires Sidekiq. Installation adds no Chronos thread or Redis/database connection per job; delivery continues through the agent's existing fixed worker pool.

The client middleware adds a top-level `chronos` metadata object to the Sidekiq envelope. It never changes the public `args` array. Only `trace_id` and `request_id` propagate, with schema version and enqueue time. The server scopes that context for the worker, measures duration and calculable queue latency, and emits one `job` event.

Collected Sidekiq fields are worker class, queue, JID, retry count, duration, queue latency, status, error class, bounded tags, and bounded arguments. At most 20 top-level arguments, 20 values per nested collection, four levels, and 512 bytes per string are traversed. Arguments then pass through the standard sensitive-key/content sanitizer before queueing. Limits reduce exposure and resource use but do not make unnecessary personal data safe to collect.

On failure, the server middleware records a failed-job observation, invokes `notify_once`, and re-raises the identical exception so Sidekiq retains ownership of retries and failure handlers. A shared execution marker prevents a nested Active Job hook and the Sidekiq middleware from sending the same exception twice. Version 0.7 aggregates the job observation; the exception retains sanitized bounded arguments. Chronos does not install an additional global Sidekiq error handler.

Known limitations for this first 0.6 prerelease:

- the compatibility contract uses Sidekiq 4/5 public middleware signatures; dedicated real Sidekiq matrix jobs must pass before status becomes `Supported`;
- Active Job propagation, Resque, and Delayed Job are subsequent 0.6 increments;
- argument collection is automatic in this prerelease; applications should avoid placing secrets or unnecessary personal data in job arguments;
- context propagation is limited to trace and request identifiers.
