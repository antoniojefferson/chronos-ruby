# Compatibility

Chronos Ruby 1.2.2 is prepared as a maintenance release of the transitional line for modern Ruby, Rails, and Sidekiq applications. Individual combinations remain `Best effort` until their dedicated CI and real-application gates pass; a stable package version does not by itself promote an unverified combination to `Supported`. Technical compatibility does not make an end-of-life Ruby, Rails, Rack, or Sidekiq release secure. Versions 1.0 and 1.1 remain the frozen legacy line.

## Core and Rack

| Ruby             | Status             | Evidence                                                                               |
| ---------------- | ------------------ | -------------------------------------------------------------------------------------- |
| 2.7–3.2          | Best effort        | Local core/security/package gates passed; remote CI/promotion evidence remains required |
| 3.3–3.4          | Best effort        | Local core/package gates passed; Rails 8 belongs to 2.x                 |
| Earlier than 2.7 | Unsupported in 1.2 | Use an appropriate frozen legacy release                                               |

## Rails

| Ruby      | Rails   | Status             | Evidence                                                                                      |
| --------- | ------- | ------------------ | --------------------------------------------------------------------------------------------- |
| 2.7–3.2   | 7.0–7.1 | Best effort        | Real Rails applications and the complete integration gate are pending                         |
| 3.1–3.4   | 7.2     | Best effort        | Feature and package checks; use a validated application combination before production rollout |
| Rails 4–6 | —       | Unsupported in 1.2 | Use a matching earlier Chronos release                                                        |

## Sidekiq

| Ruby        | Sidekiq | Status             | Evidence                                      |
| ----------- | ------- | ------------------ | --------------------------------------------- |
| 2.7–3.4     | 7.x     | Best effort        | Pinned 7.3.10 middleware-chain fixture; Redis-backed worker lifecycle is a separate gate |
| Sidekiq 4–6 | —       | Unsupported in 1.2 | Use a matching earlier Chronos release        |

Active Job uses the public `serialize`, `deserialize`, and `perform_now` extension points with a bounded namespaced field. Support follows the validated Rails pairs above. Adapters that bypass these hooks require their own evidence.

Release evidence is recorded in [Version 1.2.2 readiness](release-1.2.2-readiness.md). Historical evidence remains in [Version 1.0 readiness](release-1.0-readiness.md) and [Version 1.1 readiness](release-1.1-readiness.md).

Status meanings:

- Supported: every mandatory compatibility gate for the exact pair passes.
- Best effort: intended to work but missing a complete gate; passing focused smokes alone does not promote a pair.
- Deprecated: still tested while removal is planned.
- Unsupported: outside the declared transitional contract.

## Selected transitional smoke matrix

| Framework patch | Ruby versions | Scope |
| --- | --- | --- |
| Rails 7.0.10 | 2.7, 3.0 | Real app boot, controller/SQL, Active Job, Error Reporter, deploy generator |
| Rails 7.1.6 | 2.7, 3.1, 3.2 | Same application checks |
| Rails 7.2.4 | 3.1, 3.3, 3.4 | Same checks; Ruby >= 3.1 is required by Rails |
| Sidekiq 7.3.10 | 2.7, 3.0, 3.1, 3.2, 3.3, 3.4 | Actual client/server middleware chains; no Redis or worker process |

Framework patches are pinned in the fixture Gemfiles. Dependency locks and execution logs must be retained for promotion; PR/release CI uploads resolved lockfiles. Ruby images in the local helper follow the selected minor and print their exact runtime patch. These are technical compatibility checks, not an assertion of upstream security maintenance. See [official Rails requirements](https://guides.rubyonrails.org/v7.2.0/upgrading_ruby_on_rails.html#ruby-versions).

The local 1.2.2 runs passed every selected smoke above. Status remains Best effort because these focused gates do not close provider/SaaS/Redis-backed lifecycle and final promotion requirements.
