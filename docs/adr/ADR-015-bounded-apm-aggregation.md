# ADR-015 — Bounded local APM aggregation

## Status

Accepted for version 0.7; trace-drain behavior amended by ADR-019.

## Context

Sending every request, SQL query, and job as an independent event increases network overhead. Retaining every observation for client-side percentiles or unbounded N+1 analysis would transfer that cost to application memory.

## Decision

Aggregate request, query, and job observations by bounded low-cardinality dimensions. Store only counters, error counters, duration sum/min/max, fixed histogram buckets, component totals, status counters, and heuristic signal counters. Calculate averages locally and percentiles in the SaaS.

Use a fixed group limit, fixed query-fingerprint limit per trace, fixed batch size, and no new timer thread. Drain on observation threshold, explicit flush, and close. ADR-019 later preserves incomplete trace trackers across drains under capacity and idle-TTL limits. Normalize SQL comments and literal values before fingerprinting and never read binds. Use a `metric_batch` event through the existing sanitization, queue, retry, circuit breaker, and backlog pipeline.

## Alternatives

One event per observation was rejected as the default because delivery overhead scales directly with traffic. Retaining raw duration arrays was rejected because memory would scale with traffic. Client-side percentiles, SQL parsing dependencies, and background flush threads were rejected for the legacy line. Full SQL and bind capture was rejected for privacy and cardinality.

## Positive consequences

Delivery volume is reduced, memory remains bounded, request breakdown is available, SQL values are excluded, and the SaaS receives stable histograms suitable for percentile calculation.

## Negative consequences

Process crashes can lose undrained aggregates, idle/over-capacity trackers can be discarded and are counted, local signals are heuristic, and a defensive SQL normalizer cannot understand every database dialect.
