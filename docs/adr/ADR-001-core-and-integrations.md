# ADR-001 — Separate core and integrations

## Status

Accepted.

## Context

Chronos must support plain Ruby and several incompatible framework generations without coupling event modeling to Rails or worker libraries.

## Decision

Use hexagonal boundaries: Core, Application, Ports, Adapters, and Internal. The public `Chronos` module remains a thin facade.

## Alternatives

A single notifier class was rejected because framework hooks, HTTP, and domain rules would evolve together. A plugin framework was rejected for version 0.1 because it would add abstractions without current integrations.

## Positive consequences

Core tests run without Rails, transports are replaceable, and legacy integrations can use feature detection.

## Negative consequences

The repository contains more small files and explicit composition code.
