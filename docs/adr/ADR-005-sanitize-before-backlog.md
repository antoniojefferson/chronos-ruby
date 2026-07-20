# ADR-005 — Sanitize before backlog

## Status

Accepted and implemented in version 0.3.

## Context

Persisting unsanitized events would increase privacy and credential exposure risk.

## Decision

`PayloadSerializer` must run `Sanitizer` before `SafeSerializer`, queueing, transport, retry, or backlog. `MemoryBacklog` accepts only `SerializedEvent`. Raw notices remain transient in process memory and never enter delivery storage.

## Alternatives

Sanitizing only during final delivery is rejected because backlog data would remain exposed.

## Positive consequences

Retry storage cannot contain raw pre-filter payloads by design.

## Negative consequences

Filtering decisions cannot be changed retroactively for already accepted events.
