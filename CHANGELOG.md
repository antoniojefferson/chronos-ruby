# Changelog

All notable changes are documented here. The project follows Semantic Versioning.

## [Unreleased]

### Fixed

- legacy CI now resolves Bundler 1.17.3 through `Gem.bin_path` on RubyGems versions that do not support the `_version_` executable selector.

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
