# Compatibility

Chronos Ruby 1.1 is the current stable legacy line. Technical compatibility does not make an end-of-life Ruby, Rails, Rack, or Sidekiq release secure. The planned Ruby 2.7/Rails 6 transitional matrix remains deferred until it has dedicated CI and a real application gate.

## Core and Rack

| Ruby | Status | Evidence |
|---|---|---|
| 2.2.10 | Supported | Full unit, integration, contract, Rack, concurrency, fork, transport, privacy, and lint gate |
| 2.3.8 | Supported | Same dedicated Docker gate |
| 2.4.10 | Supported | Same dedicated Docker gate |
| 2.5.9 | Supported | Same dedicated Docker gate |
| 2.6.10 | Supported | Same dedicated Docker gate |
| 2.7 and newer | Unsupported in 1.x legacy | Belongs to the transitional or modern lines |

## Rails

| Ruby | Rails | Status | Evidence |
|---|---|---|---|
| 2.2.10 | 4.2 | Supported | Real application boot, successful/error request, SQL, view, cache, Active Job, mailer, fake endpoint, flush, and shutdown |
| 2.3.8 | 4.2 | Supported | Same dedicated application gate |
| 2.5.9 | 5.2 | Supported | Same dedicated application gate |
| 2.6.10 | 5.2 | Supported | Same dedicated application gate |
| Other Ruby/Rails pairs | — | Unsupported | No complete release gate; feature detection alone is not a support claim |

## Sidekiq

| Ruby | Sidekiq | Status | Evidence |
|---|---|---|---|
| 2.2.10 | 4.2.10 | Supported | Real-gem client/server middleware smoke with context, success/failure, and deduplication |
| 2.5.9 | 5.2.10 | Supported | Same dedicated application gate |
| Other Ruby/Sidekiq pairs | — | Unsupported | No complete release gate |

Active Job uses the public `serialize`, `deserialize`, and `perform_now` extension points with a bounded namespaced field. Support follows the validated Rails pairs above. Adapters that bypass these hooks require their own evidence.

The release workflow repeats every supported pair before publishing. Version 1.1.2 evidence is recorded in [Version 1.1.2 readiness](release-1.1.2-readiness.md); historical evidence remains in [Version 1.0 readiness](release-1.0-readiness.md) and [Version 1.1 readiness](release-1.1-readiness.md).

Status meanings:

- Supported: every mandatory compatibility gate for the exact pair passes.
- Best effort: intended to work but missing a complete gate; no 1.1 pair is advertised this way.
- Deprecated: still tested while removal is planned.
- Unsupported: outside the tested 1.1 contract.
