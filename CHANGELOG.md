# Changelog

All notable changes are documented here. The project follows Semantic Versioning.

## [Unreleased]

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
