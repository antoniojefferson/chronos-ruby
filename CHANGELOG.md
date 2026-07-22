# Changelog

All notable changes are documented here. The project follows Semantic Versioning.

## [Unreleased]

## [0.9.0.pre.4] - 2026-07-22

### Added

- `Chronos.verify_integration` and `chronos:verify_integration` send a correlated synthetic exception and report credential, project, receiver, and receipt status as bounded JSON;
- strict integration-verification response contract v1, Rails task registration, failure classification, security limits, and end-to-end tests.

### Changed

- version advanced to `0.9.0.pre.4` because `0.9.0.pre.3` had already been published before integration verification was added.

## [0.9.0.pre.3] - 2026-07-21

### Changed

- version advanced to `0.9.0.pre.3` because `0.9.0.pre.2` had already been published before these fixes were completed.

### Fixed

- exception notices now copy request and application values before freezing their immutable representation, preventing `can't modify frozen String` on repeated Rack/Rails failures;
- `WorkerPool#flush` no longer returns before a worker marks a just-popped event as active;
- release publishing now uses RubyGems Trusted Publishing with short-lived GitHub OIDC credentials, avoiding interactive MFA and long-lived API secrets in CI;
- the legacy development toolchain uses non-vulnerable Rake and RuboCop versions;
- legacy CI resolves Bundler 1.17.3 through `Gem.bin_path` on RubyGems versions that do not support the `_version_` executable selector;
- documentation verification reads source and Markdown files explicitly as UTF-8 on legacy container locales.

## [0.9.0.pre.2] - 2026-07-21

### Added

- bounded startup and runtime exception ignore rules through `config.ignore_rules` and `Chronos.ignore_if`;
- Active Job trace/request propagation without modifying public arguments, plus adapter, job/provider IDs, attempts, status, and failure telemetry;
- real-gem Sidekiq 4.2/5.2 Docker compatibility jobs;
- repeatable Rack comparison and fake-endpoint load gates;
- corrected `script/test_all` so `pipefail` no longer turns installed Rubies into false skips and an empty matrix fails;
- Airbrake migration, SemVer, deprecation, protocol stability, security review, and 1.0 readiness documentation.

### Changed

- version advanced to `0.9.0.pre.2` instead of `1.0.0` because the full external legacy matrix has not yet supplied zero-failure evidence;
- Active Job identifiers are now documented collected fields and propagated context is bounded to trace/request IDs.

### Fixed

- the Sidekiq 5 compatibility smoke resolves the shared Sidekiq 4/5 fixture inside `examples/` instead of the nonexistent `/app/sidekiq-4` path.

### Security

- local ignore rules are bounded to 100, contain callback failures, and cannot be installed remotely;
- fake-endpoint load validation rejects payloads containing the secret authentication key;
- package signing remains deferred until a trusted key lifecycle exists; protected publishing credentials remain required.

### Known limitations

- compatibility stays `Best effort` until all new and existing GitHub Actions matrix jobs pass without skips;
- end-of-life runtimes and framework dependencies retain their upstream security risk;
- Active Job adapters that bypass standard serialization/execution hooks need dedicated evidence;
- comparative results are not a performance claim and must be published with controlled environment metadata.

## [0.9.0.pre.1] - 2026-07-21

### Added

- synchronous `Chronos.notify_deploy` API with bounded environment, revision, version, repository, actor, deploy ID, service, region, and instance fields;
- fixed bounded release/deploy correlation on every new exception and telemetry envelope;
- explicit configuration for `revision`, `deploy_id`, `region`, and `instance_id`;
- automatic deploy IDs and credential removal from common HTTP/SCP repository references;
- optional idempotent Capistrano post-publish task loaded through `chronos/capistrano`;
- manual, Kamal-command, and GitHub Actions deployment examples;
- deploy/correlation contracts, tests, benchmark, module documentation, and ADR-017.

### Changed

- dependency inventory can be refreshed once after a successful deploy notification with the new release;
- deploy events use their normalized environment/service/release values in the common envelope;
- version advanced to `0.9.0.pre.1`.

### Known limitations

- `notify_deploy` does not mutate the immutable correlation of an already running agent;
- Kamal support is command/documentation based rather than a plugin;
- Capistrano must load its task DSL before the optional Chronos entry point;
- deployment policy must decide whether a `false` notification result blocks publication.

## [0.8.0.pre.1] - 2026-07-20

### Added

- optional per-instance `Net::HTTP` instrumentation with sanitized host, method, status, duration, timeout and connection-error classification;
- outbound trace/request header propagation without collecting URLs, Authorization, request bodies, response bodies, or error messages;
- external HTTP metric aggregation and traced-request `external_http` breakdown;
- cache operation, duration, hit/miss, backend, namespace, and opt-in project-scoped SHA-256 key identity;
- bounded dependency inventory containing loaded gem versions, Ruby, optional Rails/web server/database/Sidekiq detection, and configured release;
- version 0.8 configuration, contracts, tests, executable example, benchmark, module documentation, and ADR-016.

### Changed

- dependency inventory is queued at most once per configured agent instead of being attached to every exception;
- cache notification fields now use bounded backend/namespace/outcome names and omit raw keys by default;
- version advanced to `0.8.0.pre.1`.

### Known limitations

- outbound HTTP instrumentation must be enabled and installed on each selected `Net::HTTP` instance;
- Faraday, HTTP.rb, Excon, and RestClient adapters are not included;
- cache key hashing is opt-in and low-entropy keys may remain guessable;
- dependency detection uses already loaded gems and does not open a database connection or inspect lockfiles.

## [0.7.0.pre.1] - 2026-07-20

### Added

- bounded local request, SQL, and job aggregation with count, error rate, duration statistics, histograms, status codes, and component breakdown;
- `metric_batch` v1 payloads containing at most 50 sanitized metric groups;
- bounded SQL normalization, fingerprinting, adapter/operation/table/name/cache/role/shard dimensions, and sampled slow-query source;
- heuristic slow-query, repeated-query, possible N+1, long-transaction, connection-error, and deadlock signals;
- generic Rack request metrics with Rails/Rack deduplication;
- APM configuration, diagnostics, contracts, tests, example, benchmark, module documentation, and ADR-015.

### Changed

- request, query, and job observations aggregate by default instead of producing one delivery event each;
- `Chronos.flush` and `Chronos.close` drain APM aggregates before delivery shutdown;
- version advanced to `0.7.0.pre.1`.

### Known limitations

- local signals are heuristic and require server-side confirmation;
- incomplete trace trackers are cleared when aggregates drain;
- normalized SQL is defensive rather than a complete dialect parser;
- external HTTP breakdown remains version 0.8 scope.

## [0.6.0.pre.1] - 2026-07-20

### Added

- optional Sidekiq 4/5 client and server middleware loaded through `chronos/sidekiq`;
- versioned trace/request context propagation beside, never inside, public job arguments;
- Sidekiq class, queue, JID, retry count, duration, calculable latency, bounded arguments, tags, status, and error telemetry;
- shared per-job exception deduplication for nested Sidekiq and Active Job capture paths;
- Sidekiq payload contract, unit/integration tests, executable example, benchmark, module documentation, and ADR-014.

### Changed

- version advanced to `0.6.0.pre.1`;
- the public facade exposes bounded propagation context for optional process-boundary integrations.

### Known limitations

- Sidekiq 4/5 remains `Best effort` until dedicated real-gem matrix jobs pass;
- Active Job context propagation, Resque, and Delayed Job remain subsequent version 0.6 increments;
- Sidekiq argument capture is automatic, though strictly bounded and sanitized.

## [0.4.0.pre.1] - 2026-07-20

### Added

- Rack-protocol middleware for automatic exception capture with propagation of the original failure;
- request context for method, normalized route, status, duration, request ID, optional user agent, host, path, controller/action, approximate response size, user, and sanitized parameters;
- selectable context-store port with a thread-local legacy adapter and guaranteed scope cleanup;
- bounded circular breadcrumbs for custom, log, request, query, external HTTP, cache, and job categories;
- public `Chronos.with_context` and `Chronos.add_breadcrumb` APIs;
- Rack context contract, concurrency tests, module documentation, ADR, executable example, and request-overhead benchmark.

### Changed

- manual notifications now inherit the current execution context and breadcrumbs;
- version advanced to `0.4.0.pre.1`.

### Known limitations

- generic route normalization cannot identify every application-specific dynamic segment;
- thread-local context does not propagate into application-created threads or fibers;
- deferred exceptions raised only while enumerating a streaming response body are not captured;
- Rails-specific installation and route discovery remain planned for version 0.5.

## [0.3.0.pre.1] - 2026-07-20

### Added

- explicit delivery-state counters for accepted, queued, serialized, sent, retried, dropped, and rejected events;
- finite exponential retry with bounded jitter and `Retry-After` support;
- retry classification for network errors, HTTP 408, 429, and 5xx responses;
- closed, open, and half-open circuit breaker states;
- fixed-capacity in-memory backlog restricted to sanitized serialized events;
- bounded remote configuration for sampling, event types, payload limits, exact fingerprint ignores, send interval, and kill switch;
- resilience contracts, unit tests, module documentation, ADR, executable example, and outage benchmark.

### Changed

- asynchronous and synchronous delivery now pass through `DeliveryPipeline`;
- `WorkerPool` delegates delivery policy instead of sending directly through a transport;
- version advanced to `0.3.0.pre.1`.

### Known limitations

- backlog is not persisted and is lost when the process exits;
- backlog draining requires later delivery activity;
- no dedicated remote-configuration polling endpoint;
- no automatic Rack, Rails, or job integration.

## [0.2.0.pre.1] - 2026-07-19

### Added

- recursive sensitive-key sanitization with String, Symbol, and Regexp matchers;
- content detection for Bearer tokens, JWTs, e-mail addresses, CPF, CNPJ, and payment cards;
- configurable identifier hashing and IPv4 anonymization;
- bounded safe serialization with cycle and node-budget protection;
- custom privacy filters with contained failures;
- privacy contract tests, audit example, module documentation, and filtering benchmark.

### Changed

- all exception fields are sanitized before JSON serialization and transport;
- configuration snapshots now recursively freeze privacy settings;
- ADR-005 is accepted for the sanitization boundary.

### Known limitations

- sensitive-data detection is defensive and cannot replace an application privacy review;
- IPv6 anonymization is not implemented;
- no retry or backlog;
- no automatic Rack, Rails, or job integration.

## [0.1.0.pre.2] - 2026-07-19

### Changed

- prepared the second public pre-release;
- aligned the release tag with the RubyGems version format.

## [0.1.0.pre.1] - 2026-07-19

### Added

- framework-independent `Chronos` facade;
- validated immutable configuration;
- exception, backtrace, cause, and runtime normalization;
- versioned JSON exception envelope;
- bounded serialization and payload size enforcement;
- Net::HTTP transport with TLS, proxy, timeout, and response classification;
- fixed-capacity asynchronous queue and lazy worker pool;
- flush, timed shutdown, double-close, and fork handling;
- Ruby 2.2.10–2.6 legacy test matrix;
- contract, unit, integration, failure, and performance test assets.

### Known limitations

- no advanced sensitive-data sanitizer;
- no retry or backlog;
- no automatic Rack, Rails, or job integration;
- no performance monitoring or deploy events.
