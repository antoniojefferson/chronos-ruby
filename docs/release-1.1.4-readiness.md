# Version 1.1.4 release preparation

Version `1.1.4` prepares deploy automation for the stable legacy line. It packages the `chronos` CLI, explicit ENV/YAML configuration, optional provider installers and Rails/Rake adapters. It preserves Ruby >= 2.2.10 and < 2.7, the existing Rails/Sidekiq pairs, and protocol `schema_version: "1.0"`. This is a limited maintenance exception; it does not reopen general feature development on the legacy line.

## Operational contract

- No notification, generator execution, or application file changes on install, require, help, or version.
- Notify requires explicit project credentials, environment, stable publication ID, and actual published revision/version. It uses `Chronos.notify_deploy` and always closes the agent.
- Verify reuses `Chronos.verify_integration`, validates its receipt, disables dependency reporting, and does not create a deploy. A receipt is not proof of SaaS projection.
- CLI transport requires verified HTTPS. Retries and backlog are disabled for this short-lived process; transport and flush operations have bounded timeouts, not a single global process deadline.
- Exit codes: 0 confirmed/local success, 1 invalid configuration, 2 unconfirmed delivery, 3 internal failure. Warning policy only converts code 2 to 0 and retains `success=false`.
- Repeated notify calls keep deployment identity but can generate another event and consumption. Dependency events can add consumption. Do not retry blindly after an unconfirmed result.
- Installers preserve conflicting files, offer a privacy-safe proposed template, and reject destination symlinks. POSIX descriptor-relative operations prevent parent-path swaps from redirecting creation or publication. CI fragments require manual merge after the actual publication.

## Evidence and pending gates

Local Ruby 3.4 checks are supplementary evidence only. They do not establish compatibility with the supported legacy runtimes.

Before tagging, require:

- core suite, CLI, transport, privacy, shutdown/fork, and RuboCop 0.49 gates on Ruby 2.2.10, 2.3.8, 2.4.10, 2.5.9, and 2.6.10;
- Rails 4.2 on Ruby 2.2.10/2.3.8 and Rails 5.2 on Ruby 2.5.9/2.6.10, including deploy generator smoke;
- Sidekiq 4.2.10 on Ruby 2.2.10 and Sidekiq 5.2.10 on Ruby 2.5.9;
- built gem installed into clean supported runtimes, executable/help/offline diagnostics and HTTPS notification/receipt tests;
- dependency audit with the CI-pinned tooling, documentation and PR-body verification;
- query-analysis/Rack benchmarks and fake-endpoint load/privacy gates;
- authorized provider smoke tests and SaaS evidence for receipt, ingestion, identity, consumption, and projection; keep these distinct;
- reviewed source, package inspection, checksum, SPDX SBOM, and maintainer approval.

Use the [Docker test instructions](../README.md#tests). The working-tree lockfile originated from modern tooling; the isolated Docker helper resolves dependencies only in its container copy. It does not prove the direct CI workflow's dependency resolution will pass; that remains a required check.

## SaaS rollout and transitional backport

The CLI capability is introduced by legacy release `1.1.4`. The transitional main-line backport is not included in this release. The SaaS must select recipes using explicitly validated release ranges for each line, never a single cross-line minimum. Keep old script recipes for older clients and do not delete customer-edited scripts.

## Publication

No release has been published by this preparation. Never replace previously published artifacts. After all gates and approval, the release tag must be exactly `v1.1.4` and match `Chronos::VERSION`. Pushing that tag triggers the release workflow and its publication job; do not create or push it before approval. Publish through the configured Trusted Publishing workflow rather than a manual gem push.

## Security regression coverage

`spec/security/` covers SQL literal confidentiality through the final APM envelope, complete original-query validation before inspection, sensitive symbols through final serialization, cyclic/deep diagnostic input and caller ownership, and deterministic symlink/concurrent-file interleavings. Conservative SQL handling omits oversized or ambiguous queries; plan evidence remains best effort. The installer uses fixed POSIX calls through standard-library Fiddle and does not execute shell commands. Unsupported filesystem backends must fail closed.

Security-fix validation: the core/security suite passed on MRI 2.2.10, 2.3.8, 2.4.10, 2.5.9 and 2.6.10 in isolated Linux/amd64 containers: 221 RSpec examples, the complete RuboCop 0.49.1 inspection (225 files), 25 standalone source tests (127 assertions), gem build/install, local diagnostics, and six installed-executable HTTPS tests (36 assertions) per runtime. The expanded installed-gem smoke also verifies explicit Kamal hook generation and idempotent check in a path containing spaces. These results do not close the separate Rails/Sidekiq, supplier, SaaS, audit, benchmark, or remote CI gates.
