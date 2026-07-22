# Version 1.0 readiness

Version `0.9.0.pre.4` is a hardening release, not the stable release. The local suite, lint, documentation verifier, build, load test, and comparative benchmark are required evidence. The release can advance to `1.0.0` only after the GitHub Actions matrix is green for every declared legacy Ruby/framework/job combination.

| Gate | State in pre.4 |
|---|---|
| Ruby pure, Rack, Rails 4.2/5.2 | Implemented; external legacy matrix must pass |
| Sidekiq 4/5 real gems | Dedicated Docker matrix added; must pass |
| Active Job metadata/error/context | Implemented and contract-tested |
| filters, bounded ignore rules, context, breadcrumbs | Implemented and documented |
| request/SQL/job APM, deploy, retry/backlog, remote configuration | Implemented and contract-tested |
| payload fixture privacy | Contract-tested |
| public API/options/protocol review | Documented; final review required |
| Airbrake migration, SemVer, deprecation, security review | Added in pre.2 |
| fake endpoint load and repeatable comparison | Executable gates added |
| package signing | Not currently feasible; protected secret plus checksum is the interim control |

Do not change compatibility status from `Best effort` or create a `v1.0.0` tag until all external jobs and the dependency audit pass without skips.
