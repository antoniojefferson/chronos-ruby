# Compatibility

Chronos Ruby 1.2.1 is the current stable release of the transitional line for modern Ruby, Rails, and Sidekiq applications. Individual combinations remain `Best effort` until their dedicated CI and real-application gates pass; a stable package version does not by itself promote an unverified combination to `Supported`. Technical compatibility does not make an end-of-life Ruby, Rails, Rack, or Sidekiq release secure. Versions 1.0 and 1.1 remain the frozen legacy line.

## Core and Rack

| Ruby | Status | Evidence |
|---|---|---|
| 2.7–3.2 | Best effort | Transitional matrix introduced in this candidate; promotion requires green CI evidence |
| 3.3–3.4 | Best effort | Core checks run in modern CI; Rails 8-specific behavior belongs to 2.x |
| Earlier than 2.7 | Unsupported in 1.2 | Use an appropriate frozen legacy release |

## Rails

| Ruby | Rails | Status | Evidence |
|---|---|---|---|
| 2.7–3.2 | 7.0–7.1 | Best effort | Real Rails applications and the complete integration gate are pending |
| 3.1–3.4 | 7.2 | Best effort | Feature and package checks; use a validated application combination before production rollout |
| Rails 4–6 | — | Unsupported in 1.2 | Use a matching earlier Chronos release |

## Sidekiq

| Ruby | Sidekiq | Status | Evidence |
|---|---|---|---|
| 2.7–3.4 | 7.x | Best effort | Real Sidekiq 7 smoke applications are pending |
| Sidekiq 4–6 | — | Unsupported in 1.2 | Use a matching earlier Chronos release |

Active Job uses the public `serialize`, `deserialize`, and `perform_now` extension points with a bounded namespaced field. Support follows the validated Rails pairs above. Adapters that bypass these hooks require their own evidence.

Release evidence is recorded in [Version 1.2 readiness](release-1.2-readiness.md). Historical evidence remains in [Version 1.0 readiness](release-1.0-readiness.md) and [Version 1.1 readiness](release-1.1-readiness.md).

Status meanings:

- Supported: every mandatory compatibility gate for the exact pair passes.
- Best effort: intended to work but missing a complete gate; no 1.1 pair is advertised this way.
- Deprecated: still tested while removal is planned.
- Unsupported: outside the tested 1.1 contract.
