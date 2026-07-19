# ADR-006 — Versioned event contract

## Status

Accepted.

## Context

Clients and the Chronos SaaS evolve independently and require a testable compatibility boundary.

## Decision

All events use a common envelope with `schema_version`. Version 0.1 emits exception events using schema `1.0`, UUID event IDs, ISO-8601 UTC timestamps, JSON primitives, and an idempotency header.

## Alternatives

Sending Ruby object serialization or an unversioned free-form hash was rejected.

## Positive consequences

Payloads can be validated, replayed safely, and evolved with backward compatibility.

## Negative consequences

Schema evolution requires explicit server and client coordination.
