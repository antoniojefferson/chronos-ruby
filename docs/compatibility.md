# Compatibility

Chronos Ruby 0.x is the legacy line. Technical compatibility does not make an end-of-life Ruby or Rails release secure.

| Ruby | Rails integration | Status | Evidence |
|---|---|---|---|
| 2.2.10 | Rails 4.2 | Best effort | Core CI, Rails 4.2 example, dedicated smoke gate |
| 2.3.8 | Rails 4.2 / 5.0 | Best effort | Core CI and feature-detection contract; dedicated app gate incomplete |
| 2.4.10 | Rails 4.2 / 5.0 | Best effort | Core CI and feature-detection contract; dedicated app gate incomplete |
| 2.5.9 | Rails 5.2 | Best effort | Core CI, Rails 5.2 example, dedicated smoke gate |
| 2.6.10 | Rails 5.2 | Best effort | Core CI and feature-detection contract; dedicated app gate incomplete |
| 2.7 and newer | None in 0.x | Unsupported | Belongs to transitional or modern lines |

| Ruby | Sidekiq integration | Status | Evidence |
|---|---|---|---|
| 2.2.10–2.6 | Sidekiq 4 / 5 | Best effort | Middleware unit/integration contracts; dedicated real-gem matrix pending |

Version 0.5 includes Rails 4.2 and 5.2 applications plus a dedicated matrix, but this document conservatively keeps the combinations at `Best effort` until all release-gate evidence, including fake-server payload validation, is green. Rails 5.0 uses the same feature-detected public APIs but does not yet have its own example application.

Version `0.6.0.pre.1` uses the public Sidekiq 4/5 middleware signatures and remains `Best effort` until dedicated jobs exercise both real gem versions across their valid Ruby combinations.

Version `0.7.0.pre.1` keeps the same Ruby/Rails matrix and implements APM aggregation without modern concurrency or SQL-parser dependencies. Its compatibility remains `Best effort` until request/SQL/job aggregate payloads pass the dedicated fake-server gates for every listed runtime.

Status meanings:

- Supported: the complete required compatibility gate passes.
- Best effort: intended to work, but the complete gate has not passed yet.
- Deprecated: still tested while removal is planned.
- Unsupported: outside this release line.
