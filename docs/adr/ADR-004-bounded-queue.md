# ADR-004 — Bounded queue and drop policy

## Status

Accepted.

## Context

An unavailable endpoint or event burst must not grow host application memory indefinitely.

## Decision

Use a fixed-capacity in-memory queue. Producers never wait for space. When full, the newest event is dropped and counted. Worker count is fixed and threads start lazily.

## Alternatives

An unbounded queue and one thread per event were rejected. Blocking producers was rejected because telemetry must not stall application work.

## Positive consequences

Memory and thread growth are bounded and overload behavior is measurable.

## Negative consequences

Events may be dropped under sustained pressure.
