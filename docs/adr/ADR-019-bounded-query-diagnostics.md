# ADR-019 — Bounded query diagnostics and opt-in database inspection

## Status

Accepted.

## Context

Fingerprint repetition and duration identify useful SQL symptoms but do not tell the consumer which access columns were observed, whether an existing index covers them, or what the database planner estimated. Running deep analysis inside a legacy application can add latency, expose data, increase cardinality, and violate the fixed-memory requirement.

## Decision

Analyze normalized SELECT text by default with a dependency-free bounded heuristic. Emit structured diagnostics with stable code, severity (`error`, `warning`, `info`, `suggestion`), category, bounded evidence, count, and optional recommendation.

Define `Ports::QueryInspector` and keep its ActiveRecord implementation in `Chronos::Rails`. Index, statistics, and plan inspection are independent explicit opt-ins. Inspect each eligible fingerprint at most once per subscriber, cap inspected fingerprints, and require a duration threshold. Plans use `EXPLAIN` only, never `EXPLAIN ANALYZE`; DDL and automatic index creation are prohibited. Retain only allowlisted schema/planner fields and exception class names. Never retain raw SQL, binds, plan predicates, arbitrary rows, or exception messages.

Preserve trace trackers across metric drains with capacity and idle TTL. Report loss counters. Measure outer transaction time with bounded per-connection notification state. Derive approximate p50/p95/p99 from fixed histograms without retaining duration samples.

Keep new metric fields optional in the v1 JSON Schema for backward compatibility, although the new agent emits them. Consumer models use diagnostic code/severity as stable fields and treat message text as a fallback presentation value.

## Alternatives

- Server-only static analysis was rejected because existing-index comparison requires local schema evidence and immediate signals remain useful.
- Automatic `EXPLAIN ANALYZE` was rejected because it executes the query.
- Automatic `CREATE INDEX` was rejected because it can block writes, consume storage, and regress mutation workloads.
- Shipping raw SQL/plans was rejected for privacy and cardinality.
- A full SQL-parser dependency was rejected for legacy compatibility, installation cost, and dialect complexity.
- Unbounded trace/inspection caches were rejected for memory safety.

## Positive consequences

- Consumers receive actionable, typed evidence with clear confidence limits.
- Default analysis adds no database round trip.
- Opt-in inspection is read-only, sampled by fingerprint/duration, and contains adapter failures.
- Errors, warnings, information, and suggestions can map directly to observer models.
- Trace correlation no longer disappears at every aggregate flush.

## Negative consequences

- Static parsing can miss complex SQL, aliases, expressions, partial indexes, and dialect features.
- Even non-executing `EXPLAIN` and catalog reads consume a connection/planner budget and have no portable legacy timeout.
- Index recommendations do not know true selectivity, write cost, storage, or production distribution.
- Approximate percentiles use histogram upper bounds and may be coarse.
- Transaction elapsed time is measured between notification callbacks, not database wire boundaries.
