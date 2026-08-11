# Compatibility

Chronos Ruby 1.2 is the transitional line for Rails 7 and Sidekiq 7. Technical compatibility does not make an end-of-life Ruby, Rails, Rack, or Sidekiq release secure. Versions 1.0 and 1.1 remain the frozen legacy line.

## Core and Rack

| Ruby | Status | Evidence |
|---|---|---|
| 2.7–3.2 | Supported | Unit, integration, contract, Rack, concurrency, transport, privacy, and package matrix |
| 3.3–3.4 | Best effort | Core checks run in modern CI; Rails 8-specific behavior belongs to 2.x |
| Earlier than 2.7 | Unsupported in 1.2 | Use an appropriate frozen legacy release |

## Rails

| Ruby | Rails | Status | Evidence |
|---|---|---|---|
| 2.7–3.2 | 7.0–7.1 | Supported | Notifications, Error Reporter, Action Cable, Active Job, middleware, fake endpoint, flush, and shutdown |
| 3.1–3.4 | 7.2 | Best effort | Feature and package checks; use a validated application combination before production rollout |
| Rails 4–6 | — | Unsupported in 1.2 | Use a matching earlier Chronos release |

## Sidekiq

| Ruby | Sidekiq | Status | Evidence |
|---|---|---|---|
| 2.7–3.4 | 7.x | Supported | Real middleware API, client/server context, success/failure, retries, and deduplication |
| Sidekiq 4–6 | — | Unsupported in 1.2 | Use a matching earlier Chronos release |

Active Job uses the public `serialize`, `deserialize`, and `perform_now` extension points with a bounded namespaced field. Support follows the validated Rails pairs above. Adapters that bypass these hooks require their own evidence.

Historical evidence remains in [Version 1.0 readiness](release-1.0-readiness.md) and [Version 1.1 readiness](release-1.1-readiness.md).

Status meanings:

- Supported: every mandatory compatibility gate for the exact pair passes.
- Best effort: intended to work but missing a complete gate; no 1.1 pair is advertised this way.
- Deprecated: still tested while removal is planned.
- Unsupported: outside the tested 1.1 contract.
