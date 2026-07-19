# ADR-005 — Sanitize before backlog

## Status

Proposed for versions 0.2 and 0.3; no backlog exists in 0.1.

## Context

Persisting unsanitized events would increase privacy and credential exposure risk.

## Decision

Any future retry or persistent backlog must receive only data that has already passed sanitization and structural limits.

## Alternatives

Sanitizing only during final delivery is rejected because backlog data would remain exposed.

## Positive consequences

Retry storage cannot contain raw pre-filter payloads by design.

## Negative consequences

Filtering decisions cannot be changed retroactively for already accepted events.
