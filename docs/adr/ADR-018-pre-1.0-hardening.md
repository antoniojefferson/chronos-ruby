# ADR-018: Pre-1.0 hardening gates

## Decision

Keep the release at `0.9.0.pre.2` while any mandatory 1.0 evidence remains external or incomplete. Add bounded local ignore rules, Active Job envelope propagation, real Sidekiq compatibility jobs, repeatable comparative/load benchmarks, and explicit release/security policies.

## Consequences

The stable API is not promised before the full legacy matrix passes. Active Job gains one namespaced serialized field without changing arguments. Application callbacks remain bounded in count but their execution cost belongs to the application. Package checksums are used until a trusted signing lifecycle is available.
