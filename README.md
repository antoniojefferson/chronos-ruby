# Chronos Ruby

Chronos Ruby is the framework-independent client for sending Ruby application errors and bounded telemetry to Chronos. Version 0.9 adds synchronous deploy tracking and bounded release correlation across every event.

## What the gem collects

Version 0.9 can collect:

- exception class, message, structured backtrace, and chained causes;
- timestamp, severity, tags, and an optional fingerprint;
- application-supplied context, parameters, session, and user fields;
- Ruby version, engine, platform, process ID, opaque thread ID, and hostname;
- application version, environment, and service name.
- Rack method, normalized route, status, duration, request ID, host, query-free path, optional user agent, controller/action, response size, trace ID, and already-parsed parameters when the middleware is used;
- bounded breadcrumbs explicitly supplied by the application or integration.
- release, revision, deploy ID, environment, service, region, and instance correlation;
- explicit bounded deployment metadata supplied through the public API or integration.

See [Data collected](docs/data-collected.md) for the complete field table.

## What is not collected by default

Chronos Ruby does not inspect environment variables, request/response bodies, cookies, Authorization headers, source code, database contents, lockfiles, or gem paths. Dependency reporting reads only already loaded gem names and versions once per agent. Application-supplied fields are recursively sanitized, but applications should still avoid sending unnecessary personal, health, financial, or authentication data.

## Supported Ruby and Rails versions

Version 0.x targets Ruby 2.2.10 through Ruby 2.6. Version 0.5 provides best-effort Rails 4.2 through 5.2 integration through public framework APIs and feature detection. All supported combinations must pass dedicated CI before being listed as supported.

See [Compatibility](docs/compatibility.md).

## Plain Ruby installation

The current public build is a pre-release. Add its exact version to the application's `Gemfile`:

```ruby
gem "chronos-ruby", "0.9.0.pre.2"
```

Install with a Bundler version compatible with the application. For the oldest supported runtime:

```bash
gem install bundler -v 1.17.3
bundle _1.17.3_ install
```

Without Bundler:

```bash
gem install chronos-ruby --pre
```

## Rails installation

Version 0.5 exposes Rails support explicitly, keeping Rails and ActiveSupport out of plain Ruby applications:

```ruby
gem "chronos-ruby", "0.9.0.pre.2", :require => "chronos/rails"
```

Generate the initializer with:

```bash
rails generate chronos:install
```

The Railtie installs the Rack middleware and notification subscribers idempotently. Automatic integration is disabled in test and console by default and can be controlled with `rails_enabled`, `rails_capture_in_test`, `rails_capture_in_console`, and `rails_capture_user_agent`. See [Rails 4.2 and 5.2 integration](docs/modules/rails-legacy.md).

## Minimum configuration

`project_id`, `project_key`, and an HTTPS `host` are required while the agent is enabled:

```ruby
require "chronos"

Chronos.configure do |config|
  config.project_id = ENV["CHRONOS_PROJECT_ID"]
  config.project_key = ENV["CHRONOS_PROJECT_KEY"]
  config.host = "https://chronos.example.com"
  config.environment = ENV["APP_ENV"] || "production"
  config.service_name = "billing"
  config.app_version = ENV["APP_VERSION"]
end
```

HTTPS verification is enabled by default. HTTP requires explicitly setting `ssl_verify = false` and should only be used with a local test server.

## Automatic capture

Rack applications can capture unhandled exceptions automatically and preserve the application error semantics:

```ruby
use Chronos::Integrations::Rack::Middleware,
    :include_user_agent => false
```

The middleware notifies asynchronously and re-raises the same exception. It never reads the request body, raw query string, cookies, authorization headers, or response body. See [Rack integration and context](docs/modules/rack-context.md).

## Manual capture

Asynchronous capture is recommended for application code:

```ruby
begin
  perform_payment
rescue StandardError => error
  Chronos.notify(error, :tags => ["payment"])
  raise
end
```

Synchronous capture waits for the HTTP result and is useful in scripts or controlled shutdown paths:

```ruby
delivered = Chronos.notify_sync(RuntimeError.new("import failed"))
```

Both methods return `false` instead of allowing an internal agent error to escape.

## User context

User data is opt-in and must contain only values your application is allowed to send:

```ruby
Chronos.notify(error, :user => {"id" => "customer-42", "role" => "operator"})
```

Version 0.4 sanitizes this context before delivery and before it can enter retry storage. Data minimization remains the application's responsibility.

## Breadcrumbs

Breadcrumbs use a fixed circular buffer scoped to the current execution:

```ruby
Chronos.add_breadcrumb(
  :category => "custom",
  :message => "payment started",
  :metadata => {"provider" => "example"}
)
```

No log, SQL, HTTP, cache, job, request body, or response body payload is collected automatically. Unknown categories become `custom`, and metadata is bounded and sanitized before queueing.

## Filters and LGPD

Version 0.4 recursively redacts sensitive keys and detects Bearer tokens, JWTs, e-mail addresses, CPF, CNPJ, and valid payment-card candidates in free text. IPv4 addresses are anonymized by default. Applications can add blocklist matchers, hash selected identifiers, or install custom filters:

```ruby
Chronos.configure do |config|
  # required options omitted
  config.blocklist_keys += [:medical_record, /bank_account/i]
  config.hash_keys += [:customer_id]
  config.filters << proc { |key, value| key.to_s == "internal_reference" ? "[REMOVED]" : value }
end
```

Sanitization runs before queueing and transport. See [Privacy and LGPD](docs/privacy-lgpd.md) for behavior, limitations, health and financial examples, and a payload audit procedure.

## Ignore rules

Entire environments can be ignored:

```ruby
Chronos.configure do |config|
  # required options omitted
  config.ignored_environments = ["development", "test"]
end
```

Version `0.9.0.pre.2` adds bounded local rules after configuration:

```ruby
Chronos.ignore_if do |notice|
  notice.exception_class == "SomeExpectedError"
end
```

Rules receive an immutable normalized notice, run before serialization/queueing, and must return exactly `true` to discard. The default limit is 20 and the hard configurable maximum is 100. A failing rule is contained. See [Bounded local ignore rules](docs/modules/ignore-rules.md).

## Performance monitoring

Version 0.7 aggregates request, query, and job observations into bounded `metric_batch` events. Groups include count, error count/rate, total/min/max/average duration, fixed histogram buckets, status counts, and component breakdown. Percentiles are calculated in the SaaS without retaining every local duration.

SQL comments and literal values are removed before a bounded normalized query and SHA-256 fingerprint are produced. Binds are never read. Slow, repeated, possible N+1, long-transaction, connection-error, and deadlock signals are heuristic and require server-side confirmation. Group count, active trace count, fingerprints per trace, histogram buckets, and batch size all have fixed limits. See [Essential APM aggregation](docs/modules/apm-aggregation.md).

```ruby
Chronos.configure do |config|
  # required connection settings omitted
  config.apm_enabled = true
  config.apm_max_groups = 200
  config.apm_flush_count = 100
  config.apm_batch_size = 50
  config.apm_max_queries_per_request = 100
  config.apm_slow_query_threshold_ms = 500.0
  config.apm_n_plus_one_threshold = 5
end
```

## Sidekiq and Active Job

Version `0.6.0.pre.1` adds optional Sidekiq 4/5 middleware:

```ruby
gem "sidekiq", "~> 5.0"
gem "chronos-ruby", "0.9.0.pre.2", :require => "chronos/sidekiq"
```

The client middleware propagates only trace/request identifiers in a versioned Sidekiq-envelope field and never changes worker arguments. The server records class, queue, JID, retry count, duration, calculable queue latency, bounded arguments/tags, status, and error class. Values pass through the shared sanitizer before delivery. Failed jobs are notified once and the original exception is re-raised. See [Sidekiq 4/5 legacy integration](docs/modules/sidekiq-legacy.md).

When Active Job is available, the Rails integration propagates only bounded trace/request identifiers in a namespaced serialized field without changing job arguments. It records adapter, job/provider IDs, class, queue, attempts, duration, status, and error class, and captures a supplied failure once. See [Active Job legacy integration](docs/modules/active-job.md).

## External HTTP, cache, and dependencies

Version 0.8 instruments only explicitly selected `Net::HTTP` connection objects, avoiding a global monkey patch:

```ruby
Chronos.configure do |config|
  # required connection settings omitted
  config.external_http_enabled = true
  config.external_http_trace_headers = true
end

http = Net::HTTP.new("payments.example.com", 443)
http.use_ssl = true
Chronos.instrument_net_http(http)
```

The wrapper records only sanitized host, method, status, duration, timeout, connection-error flag, and error class. It propagates `X-Chronos-Trace-ID` and `X-Chronos-Request-ID` when available and never reads URL path/query, Authorization, request body, response body, or error message.

Rails cache telemetry omits raw keys by default. Set `cache_key_mode = :sha256` to emit a project-scoped hash; `:none` is the default. Dependency reporting is enabled by default, reads at most 100 already loaded gem specs, and emits one independent `dependencies` event per agent. Set `dependency_reporting = false` to disable it. See [External HTTP](docs/modules/external-http.md), [Cache observability](docs/modules/cache-observability.md), and [Dependency inventory](docs/modules/dependencies.md).

## Deploy tracking

Version 0.9 sends deployment metadata synchronously and adds a bounded correlation block to every event:

```ruby
Chronos.notify_deploy(
  :environment => "production",
  :revision => ENV["GIT_SHA"],
  :version => ENV["APP_VERSION"],
  :repository => "owner/repository",
  :actor => ENV["DEPLOY_USER"]
)
```

Configure `app_version`, `revision`, `deploy_id`, `environment`, `service_name`, `region`, and `instance_id` in each newly deployed process so subsequent telemetry carries the same release identity. The gem never scans environment variables or Git automatically.

Optional Capistrano support loads through `chronos/capistrano`. Manual, Kamal-command, and GitHub Actions examples share the explicit deploy command under `examples/deploy/`. See [Deploy tracking and release correlation](docs/modules/deploy-tracking.md).

## Asynchronous queue

The queue has a fixed capacity and drops the newest event when full. Worker threads are created lazily after the first accepted event. The default capacity is 100 events with one worker.

```mermaid
flowchart LR
  E[Exception] --> N[Notice builder]
  N --> P[Privacy sanitizer]
  P --> S[Safe bounded serializer]
  S --> D[Delivery pipeline]
  D --> Q[Bounded queue]
  Q --> W[Fixed worker pool]
  W --> R[Retry and circuit breaker]
  R --> H[Net::HTTP transport]
  R --> B[Bounded memory backlog]
```

Use `Chronos.flush(timeout)` to wait for accepted events and `Chronos.close(timeout)` during shutdown. Workers are recreated after a process fork.

## Retry and backlog

The resilience layer introduced in version 0.3 retries network errors, HTTP `408`, `429`, and `5xx` responses with exponential backoff, bounded jitter, and a finite attempt count. Other `4xx` responses are permanent and are not retried. A circuit breaker pauses requests after repeated failures, preventing retry storms.

After retries are exhausted, the already sanitized `SerializedEvent` may enter a fixed-capacity memory backlog. The backlog drops new items when full, is lost when the process exits, and never writes to disk. A later successful half-open probe drains backlog items as new events arrive.

The SaaS may return a JSON policy in the bounded `X-Chronos-Remote-Configuration` response header. Only sampling rate, enabled event types, a lower payload limit, exact ignored fingerprints, send interval, and kill switch are accepted. Remote values cannot change the host, project credentials, TLS, local maximums, code, or regular expressions. See [Retry and backlog](docs/modules/retry-backlog.md) and [Remote configuration](docs/modules/remote-configuration.md).

## How it works internally

The code follows hexagonal boundaries:

- `Chronos::Core` contains immutable notices, sanitization, and safe normalization;
- `Chronos::Application` coordinates capture;
- `Chronos::Application::DeliveryPipeline` owns bounded retry and remote policy;
- `Chronos::Ports` defines delivery behavior;
- `Chronos::Adapters` implements Net::HTTP delivery and thread-local context;
- `Chronos::Integrations::Rack` implements optional automatic Rack capture;
- `Chronos::Rails` implements the optional Railtie, installer, generator, and public-notification adapters;
- `Chronos::Internal` owns bounded queueing, workers, and defensive logging.

The core has no dependency on Rails, Rack, Sidekiq, or ActiveSupport. See [Architecture](docs/architecture.md).

## Environment-specific configuration

Configuration values are explicit; the gem never scans the process environment. Read only the variables your application chooses:

```ruby
Chronos.configure do |config|
  config.project_id = ENV["CHRONOS_PROJECT_ID"]
  config.project_key = ENV["CHRONOS_PROJECT_KEY"]
  config.host = ENV["CHRONOS_HOST"]
  config.environment = ENV["APP_ENV"] || "production"
  config.enabled = ENV["CHRONOS_ENABLED"] != "false"
  config.queue_size = 100
  config.workers = 1
  config.timeout = 5.0
  config.open_timeout = 2.0
  config.max_retries = 3
  config.retry_base_interval = 0.5
  config.retry_max_interval = 30.0
  config.retry_jitter = 0.25
  config.backlog_size = 100
  config.circuit_failure_threshold = 5
  config.circuit_reset_timeout = 30.0
  config.remote_configuration = true
  config.context_store = :thread_local
  config.breadcrumb_capacity = 20
  config.breadcrumb_max_bytes = 2048
  config.apm_enabled = true
  config.apm_max_groups = 200
  config.apm_flush_count = 100
  config.external_http_enabled = false
  config.cache_key_mode = :none
  config.dependency_reporting = true
  config.app_version = ENV["APP_VERSION"]
  config.revision = ENV["GIT_SHA"]
  config.deploy_id = ENV["DEPLOY_ID"]
  config.region = ENV["REGION"]
  config.instance_id = ENV["INSTANCE_ID"]
end
```

All options are documented in [Configuration](docs/configuration.md).

## Troubleshooting

Configuration errors are raised during `Chronos.configure`. Capture and delivery errors are contained and optionally reported to the configured logger. Verify credentials, HTTPS certificates, timeouts, and `Chronos.flush` results. See [Troubleshooting](docs/troubleshooting.md).

## Benchmark

Run the version 0.9 benchmarks with:

```bash
bundle _1.17.3_ exec ruby benchmarks/capture_exception.rb
bundle _1.17.3_ exec ruby benchmarks/serialization.rb
bundle _1.17.3_ exec ruby benchmarks/filtering.rb
bundle _1.17.3_ exec ruby benchmarks/queue.rb
bundle _1.17.3_ exec ruby benchmarks/retry_backlog.rb
bundle _1.17.3_ exec ruby benchmarks/request_overhead.rb
bundle _1.17.3_ exec ruby benchmarks/rails_notifications.rb
bundle _1.17.3_ exec ruby benchmarks/sidekiq_middleware.rb
bundle _1.17.3_ exec ruby benchmarks/apm_aggregation.rb
bundle _1.17.3_ exec ruby benchmarks/external_http.rb
bundle _1.17.3_ exec ruby benchmarks/correlation.rb
```

Results depend on runtime, hardware, and payload. No performance comparison is claimed until repeatable measurements are published.

## Migration from Airbrake

An Airbrake migration guide will be added before the legacy 1.0 release. Version 0.9 does not claim API compatibility or automatic replacement.

## Local development

Clone the repository, install Bundler 1.17.3, and run setup:

```bash
gem install bundler -v 1.17.3
bin/setup
```

Open an interactive console:

```bash
bin/console
```

Install the current source locally:

```bash
bundle _1.17.3_ exec rake install
```

## Tests

Run the complete suite on the current Ruby:

```bash
bundle _1.17.3_ exec rake
```

The legacy CI matrix covers Ruby 2.2.10, 2.3.8, 2.4.10, 2.5.9, and 2.6.10. Network integration tests use a local fake HTTP server.

## Contributing

Open an issue before introducing a new public API or dependency. Every public class requires YARD documentation, tests, module documentation, and compatibility evidence. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

Never include credentials in event context or logs. Report vulnerabilities privately according to [SECURITY.md](SECURITY.md). Ruby 2.2 through 2.6 are end-of-life; Chronos provides technical compatibility, not runtime security maintenance.

## License

Chronos Ruby is distributed under the terms of the MIT License. See [LICENSE.txt](LICENSE.txt).
