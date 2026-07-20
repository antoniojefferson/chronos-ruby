# ADR-014 — Sidekiq context in the job envelope

## Status

Accepted for version 0.6.

## Context

Sidekiq clients and servers usually run in different processes. Chronos needs correlation without changing the worker's public arguments, opening per-job resources, or allowing nested Active Job and Sidekiq hooks to duplicate the same exception.

## Decision

Use Sidekiq 4/5 public client and server middleware. Store a versioned `chronos` object beside `args`, containing only enqueue time, trace ID, and request ID. Never append metadata to `args`. On the server, establish a job execution context with a shared exception-deduplication map, emit bounded job telemetry, notify failures through `notify_once`, and re-raise the original exception. Do not install a global Sidekiq error handler.

Limit job arguments before the common sanitizer and serializer: 20 top-level arguments, 20 items per collection, depth four, and 512 bytes per string. Sanitization remains mandatory before queueing, retry, backlog, or transport.

## Alternatives

Appending a context argument was rejected because it changes worker arity and application-visible data. A process-global context was rejected because concurrent jobs would leak correlation. A global error handler plus server middleware was rejected because it creates duplicate capture paths. Per-job delivery threads or Redis connections were rejected because lifecycle and resource ownership belong to Sidekiq and the existing bounded agent.

## Positive consequences

Worker signatures remain compatible, cross-process correlation is bounded, nested integrations share deduplication, and Sidekiq retains retry semantics.

## Negative consequences

The Sidekiq envelope grows slightly, only two context identifiers propagate, and automatic argument collection still requires application privacy review.
