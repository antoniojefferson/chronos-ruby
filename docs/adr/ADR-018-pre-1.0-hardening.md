# ADR-018: Pre-1.0 hardening gates

## Status

Concluído pela versão 1.0.0.

## Decision

Keep the release in prerelease while any mandatory 1.0 evidence remains external or incomplete. Promote only after bounded local ignore rules, Active Job envelope propagation, real Sidekiq compatibility jobs, repeatable comparative/load benchmarks, and explicit release/security policies are present and green.

## Consequences

The complete candidate matrix passed before the 1.0 promotion. Active Job has one namespaced serialized field without changing arguments. Application callbacks remain bounded in count but their execution cost belongs to the application. Trusted Publishing, package checksums and SBOMs are used until a trusted signing lifecycle is available.
