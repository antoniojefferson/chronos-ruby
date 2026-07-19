# ADR-003 — Net::HTTP for legacy transport

## Status

Accepted.

## Context

An HTTP client dependency can abandon old Ruby versions or conflict with the host application bundle.

## Decision

Implement the version 0.x transport with `Net::HTTP`, explicit timeouts, TLS verification, optional proxy support, no automatic redirects, and result classification.

## Alternatives

Faraday and other clients were deferred because they add dependencies and version-resolution risk.

## Positive consequences

The agent has no runtime gem dependency and controls legacy behavior directly.

## Negative consequences

Connection pooling and middleware conveniences require explicit implementation later.
