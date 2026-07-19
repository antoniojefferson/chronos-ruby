# ADR-002 — Compatibility through version lines

## Status

Accepted.

## Context

One dependency and syntax baseline cannot safely serve Ruby 2.2 and modern fiber-aware Ruby releases indefinitely.

## Decision

Use 0.x for Ruby 2.2.10–2.6, 1.x for transitional Ruby 2.7–3.2, and 2.x for Ruby 3.3 and newer. Support is declared only after the required CI and integration evidence exists.

## Alternatives

A single ever-growing major line was rejected because modern dependencies would eventually break installation in legacy applications.

## Positive consequences

Legacy applications receive conservative fixes while modern code can adopt runtime capabilities safely.

## Negative consequences

Critical protocol and security fixes may need backports across maintained lines.
