# ADR-015 — Bounded local APM aggregation

## Status

Accepted for version 0.7.

## Context

Sending every request, SQL query, and job as an independent event increases network overhead. Retaining every observation for client-side percentiles or unbounded N+1 analysis would transfer that cost to application memory.

## Decision

Aggregate request, query, and job observations by bounded low-cardinality dimensions. Store only counters, error counters, duration sum/min/max, fixed histogram buckets, component totals, status counters, and heuristic signal counters. Calculate averages locally and percentiles in the SaaS.

Use a fixed group limit, fixed query-fingerprint limit per trace, fixed batch size, and no new timer thread. Drain on observation threshold, explicit flush, and close. Clear incomplete trace trackers during drain. Normalize SQL comments and literal values before fingerprinting and never read binds. Use a `metric_batch` event through the existing sanitization, queue, retry, circuit breaker, and backlog pipeline.

## Alternatives

One event per observation was rejected as the default because delivery overhead scales directly with traffic. Retaining raw duration arrays was rejected because memory would scale with traffic. Client-side percentiles, SQL parsing dependencies, and background flush threads were rejected for the legacy line. Full SQL and bind capture was rejected for privacy and cardinality.

## Positive consequences

Delivery volume is reduced, memory remains bounded, request breakdown is available, SQL values are excluded, and the SaaS receives stable histograms suitable for percentile calculation.

## Negative consequences

Process crashes can lose undrained aggregates, incomplete trackers are discarded on drain, local signals are heuristic, and a defensive SQL normalizer cannot understand every database dialect.
