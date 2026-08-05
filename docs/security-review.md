# Security review for 1.1.0

Review date: 2026-08-05. Scope: capture, serialization, transport, query analysis/inspection, integration verification, remote configuration, framework/job integrations, stable release workflow, examples, and fixtures.

Verified by contracts and implementation review:

- the secret project key is sent only in an authentication header and never in the event body;
- sanitization and payload limits run before queueing, retry, backlog, or transport;
- queue, workers, retries, delays, circuit state, backlog, breadcrumbs, APM groups, dependencies, ignore rules, and propagated identifiers are bounded;
- TLS verification is default and plain HTTP requires explicit `ssl_verify = false`;
- remote configuration is size-limited, allowlisted, and cannot replace credentials/host or install executable rules;
- integrations contain agent failures and do not collect bodies, authorization, raw SQL/binds, mail content, or raw cache keys;
- Active Job propagation uses a namespaced v1 field containing only bounded trace/request identifiers and does not alter job arguments;
- fixture privacy is enforced by contract tests and dependency advisories are checked by the security workflow.
- integration verification accepts only a strict correlated response and never exposes raw receiver bodies, credentials, stack traces, paths, SQL, or internal architecture.
- normalized query analysis is bounded by fingerprint; raw SQL and binds are never transmitted;
- database inspection is disabled by default, read-only, limited by duration/fingerprint, and never executes `EXPLAIN ANALYZE` or DDL;
- plan predicates, arbitrary planner text, database rows, and exception messages are excluded; only allowlisted schema/planner fields and error classes remain;
- new APM properties are additive/optional under protocol v1, and diagnostics/evidence pass through the common sanitizer and serializer limits.

Residual risks: supported Ruby/Rails versions are end-of-life; opt-in catalog and planner calls add database work and lack one portable timeout across legacy adapters; static index recommendations remain heuristic; in-memory backlog is lost at exit; application filters/ignore rules execute application code; project/schema identifiers and documented job IDs may be personal data in some deployments; package signing is not enabled because no trusted certificate/key lifecycle exists. Stable artifacts use a protected environment, Trusted Publishing, SHA-256 checksums and SPDX SBOMs until signing can be operated safely.
