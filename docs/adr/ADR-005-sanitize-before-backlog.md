# ADR-005 — Sanitize before backlog

## Status

Accepted for version 0.2; no backlog exists yet.

## Context

Persisting unsanitized events would increase privacy and credential exposure risk.

## Decision

`PayloadSerializer` must run `Sanitizer` before `SafeSerializer`, queueing, transport, or any future retry and persistent backlog. Raw notices remain transient in process memory and never enter delivery storage.

## Alternatives

Sanitizing only during final delivery is rejected because backlog data would remain exposed.

## Positive consequences

Retry storage cannot contain raw pre-filter payloads by design.

## Negative consequences

Filtering decisions cannot be changed retroactively for already accepted events.
