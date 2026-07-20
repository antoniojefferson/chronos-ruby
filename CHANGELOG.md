# Changelog

All notable changes are documented here. The project follows Semantic Versioning.

## [Unreleased]

### Fixed

- release publishing now updates RubyGems to a Ruby 2.6-compatible version that supports `GEM_HOST_API_KEY`.
- Updated the legacy development toolchain to non-vulnerable Rake and RuboCop versions.
- legacy CI now resolves Bundler 1.17.3 through `Gem.bin_path` on RubyGems versions that do not support the `_version_` executable selector.
- documentation verification now reads source and Markdown files explicitly as UTF-8 on legacy container locales.

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
