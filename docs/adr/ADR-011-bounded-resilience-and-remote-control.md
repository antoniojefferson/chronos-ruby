# ADR-011 — Bounded resilience and restricted remote control

## Status

Accepted for version 0.3.

## Context

Chronos must tolerate prolonged SaaS outages in legacy applications without unbounded memory, unlimited retries, extra per-event threads, unsanitized storage, or a remote-control channel capable of changing security boundaries.

## Decision

Place retry orchestration in `DeliveryPipeline`. Use finite exponential backoff with bounded positive jitter, a simple closed/open/half-open circuit breaker, and a fixed-capacity in-memory backlog that accepts only sanitized `SerializedEvent` values. Do not persist events to disk in version 0.3.

Accept remote policy only from a size-limited JSON response header after successful authenticated event delivery. Apply a fixed scalar allowlist and local upper bounds. Reject executable content, remote regular expressions, host, credentials, TLS, and capacity changes.

## Alternatives

Retry inside `NetHttpTransport` was rejected because transport classification and delivery policy would become coupled. An unbounded queue was rejected because endpoint availability would control host memory. Immediate disk persistence was rejected because permissions, rotation, expiry, checksums, corruption, and privacy need an independent design. Arbitrary remote JSON or code callbacks were rejected as an unsafe control plane.

## Positive consequences

Outage memory remains bounded, retry storms are contained, transport stays replaceable, privacy precedes backlog, and remote operators can reduce or stop later collection without changing endpoint security.

## Negative consequences

Memory backlog is lost on restart and drains only when later delivery activity occurs. Synchronous notification may wait through retry delays. Process-local sampling is approximate. A response header limits policy size and complexity.
