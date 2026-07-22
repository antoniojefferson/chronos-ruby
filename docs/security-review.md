# Security review for 0.9.0.pre.3

Review date: 2026-07-21. Scope: capture, serialization, transport, remote configuration, framework/job integrations, release workflow, examples, and fixtures.

Verified by contracts and implementation review:

- the secret project key is sent only in an authentication header and never in the event body;
- sanitization and payload limits run before queueing, retry, backlog, or transport;
- queue, workers, retries, delays, circuit state, backlog, breadcrumbs, APM groups, dependencies, ignore rules, and propagated identifiers are bounded;
- TLS verification is default and plain HTTP requires explicit `ssl_verify = false`;
- remote configuration is size-limited, allowlisted, and cannot replace credentials/host or install executable rules;
- integrations contain agent failures and do not collect bodies, authorization, raw SQL/binds, mail content, or raw cache keys;
- Active Job propagation uses a namespaced v1 field containing only bounded trace/request identifiers and does not alter job arguments;
- fixture privacy is enforced by contract tests and dependency advisories are checked by the security workflow.

Residual risks: supported Ruby/Rails versions are end-of-life; in-memory backlog is lost at exit; application filters/ignore rules execute application code; project identifiers and documented job IDs may be personal data in some deployments; package signing is not enabled because no trusted certificate/key lifecycle exists. Release artifacts should use protected environments and published SHA-256 checksums until signing can be operated safely.
