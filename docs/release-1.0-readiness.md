# Version 1.0 release evidence

Version `1.0.0` is the first stable legacy release. Promotion was based on the complete candidate commit `ce7c67852dd39406f514499b0347a67c5b09bb8c`; future tags must pass the same gates again inside the release workflow before publishing.

| Gate | Evidence for the candidate | Enforcement for the tag |
|---|---|---|
| Ruby 2.2.10–2.6.10 | [Legacy CI: success](https://github.com/antoniojefferson/chronos-ruby/actions/runs/29891291304) | `legacy-core` matrix |
| Rails 4.2/5.2 applications | [Legacy Rails CI: success](https://github.com/antoniojefferson/chronos-ruby/actions/runs/29891291287) | `legacy-rails` matrix |
| Sidekiq 4/5 real gems | [Legacy Sidekiq CI: success](https://github.com/antoniojefferson/chronos-ruby/actions/runs/29891291327) | `legacy-sidekiq` matrix |
| Documentation and package | [Repository checks: success](https://github.com/antoniojefferson/chronos-ruby/actions/runs/29891291350) | `release-readiness` plus publish build |
| Dependency audit | [Security: success](https://github.com/antoniojefferson/chronos-ruby/actions/runs/30251211355) | scheduled and pull-request security workflow |
| Unit/integration/contracts/lint | 179 examples, 0 failures; 197 files, 0 offenses on Ruby 2.2.10 | every core matrix job |
| Payload privacy | Contract tests reject secrets in payload and retry backlog | every core matrix job and fake-endpoint load gate |
| API/options/protocol | Public facade, configuration table, v1 schemas, SemVer and deprecation policy reviewed | documentation verifier and contract suite |
| Airbrake migration | Staged migration and rollback guide | documentation verifier |
| Load and repeatable comparison | Local bounded fake endpoint plus median/MAD Rack comparison | `release-readiness` job |
| Security/release artifacts | Security review, Trusted Publishing, SHA-256 and SPDX SBOM | publish job after all dependencies pass |
| Package signing | Not currently feasible without a trusted key lifecycle | documented residual control: OIDC publishing, checksum and SBOM |

`publish` depends on all four release jobs. A failed or skipped supported runtime/framework/job pair, documentation check, comparison, or load test prevents RubyGems publication.
