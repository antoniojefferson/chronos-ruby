# ADR-012 — Rack capture with selectable execution context

## Status

Accepted for version 0.4.

## Context

Automatic Rack capture needs request-scoped state, but the legacy line cannot rely on modern fiber-local APIs. Loading the plain Ruby gem must not force Rack into applications that do not use it. Request and response bodies also carry disproportionate privacy and performance risk.

## Decision

Implement a Rack-protocol middleware without a runtime Rack dependency. Catch failures from the downstream application call, notify asynchronously, and re-raise the same exception. Never read `rack.input`, raw query strings, cookies, authorization headers, or response body enumeration. Use already-parsed parameter hashes only.

Define a `ContextStore` port and use a selectable thread-local adapter by default. Restore nested scopes in `ensure`. Keep breadcrumbs in a fixed circular per-execution buffer and sanitize them with the rest of the event before queueing.

## Alternatives

Requiring Rack from the core was rejected because it would add dependency and resolution risk to plain Ruby legacy applications. Global or process-wide context was rejected because concurrent requests would leak data. Automatic body parsing and body proxies were deferred because they change I/O behavior and complicate streaming lifecycle ownership.

## Positive consequences

Plain Ruby loading remains dependency-free, concurrent request context is isolated, middleware failure semantics are preserved, and diagnostic memory is bounded.

## Negative consequences

Thread-local context does not propagate to application-created threads or fibers. Generic route normalization is less precise than router-specific integration. Exceptions raised only during deferred response-body enumeration are outside version 0.4 capture.
