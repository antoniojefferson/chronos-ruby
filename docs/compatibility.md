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
| 2.2.10 | Sidekiq 4.2.10 | Best effort | Unit/integration contracts and dedicated real-gem Docker job |
| 2.5.9 | Sidekiq 5.2.10 | Best effort | Unit/integration contracts and dedicated real-gem Docker job |

Version 0.5 includes Rails 4.2 and 5.2 applications plus a dedicated matrix, but this document conservatively keeps the combinations at `Best effort` until all release-gate evidence, including fake-server payload validation, is green. Rails 5.0 uses the same feature-detected public APIs but does not yet have its own example application.

Version `0.9.0.pre.2` adds dedicated Sidekiq 4.2.10 and 5.2.10 real-gem jobs. Status remains `Best effort` until both external jobs pass on the release candidate.

Active Job propagation uses the standard `serialize`, `deserialize`, and `perform_now` extension points with a namespaced bounded field. Rails 4.2/5.2 example jobs and unit contracts provide evidence; the complete external matrix must still pass before stable support is declared.

Version `0.7.0.pre.1` keeps the same Ruby/Rails matrix and implements APM aggregation without modern concurrency or SQL-parser dependencies. Its compatibility remains `Best effort` until request/SQL/job aggregate payloads pass the dedicated fake-server gates for every listed runtime.

Version `0.8.0.pre.1` uses per-object `Module#prepend`, legacy `Net::HTTP`, standard-library SHA-256, and loaded-spec feature detection. It adds no runtime dependency and keeps the same matrix. Outbound HTTP, cache, and dependency gates must pass every listed runtime before support is promoted.

Version `0.9.0.pre.1` adds only standard-library URI/SecureRandom processing, bounded hashes, and the existing synchronous delivery path. Capistrano is optional and feature-detected; Kamal and GitHub Actions integrations are commands/examples. The Ruby/Rails matrix remains unchanged and `Best effort` until deploy/correlation payload gates pass every listed runtime.

Status meanings:

- Supported: the complete required compatibility gate passes.
- Best effort: intended to work, but the complete gate has not passed yet.
- Deprecated: still tested while removal is planned.
- Unsupported: outside this release line.
