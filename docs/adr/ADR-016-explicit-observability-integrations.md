# ADR-016 — Explicit and privacy-bounded observability integrations

## Status

Accepted for version 0.8.

## Context

Outbound calls, cache behavior, and runtime dependencies materially improve diagnosis, but global HTTP monkey patches and raw cache/dependency data create compatibility, cardinality, and privacy risks in legacy applications.

## Decision

Instrument only explicitly supplied `Net::HTTP` instances with a per-object prepended module. Preserve method, streaming block, response, and exception semantics. Collect only bounded host/outcome/timing fields and propagate only Chronos correlation headers.

Normalize Rails cache notifications through a core value normalizer. Omit raw keys by default and permit only an explicit project-scoped SHA-256 mode. Never inspect values.

Build one bounded dependency event per agent from already loaded gem specs and feature-detected constants. Do not inspect lockfiles or paths, activate dependencies, or open database connections. Route every event through the existing sanitizer, bounded queue, retry, circuit breaker, and backlog pipeline.

## Alternatives

A global `Net::HTTP` patch was rejected because it changes unrelated connections and increases conflict risk. Capturing full URLs, headers, bodies, cache keys, or lockfiles was rejected for privacy and cardinality. Attaching dependencies to every exception was rejected for redundant payload cost. Automatic Faraday and other client adapters were deferred until demand and official middleware boundaries are validated.

## Consequences

Applications choose exactly which HTTP clients are instrumented, native errors remain intact, and memory/data volume stay bounded. The tradeoffs are explicit setup per connection, partial dependency inventories when gems load late, pseudonymous rather than anonymous cache hashes, and no coverage for other HTTP clients in this release.
