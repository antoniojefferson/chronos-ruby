# Transitional deploy automation port

Base: main 1.2.1 (`b31d703`), branch feat/transitional-deploy-automation-1.2.2. The cherry-picked CLI and security behavior is retained; the gemspec remains Ruby >= 2.7 and < 3.5. Version 1.2.2 is a limited port, not the planned 2.x migration.

Review against main confirmed the existing Rails Error Reporter, fiber-aware context, Action Cable, Faraday, W3C/OpenTelemetry integration paths remain in place. Agent context changes are limited to bounded copies/merge and breadcrumb preservation. Tests exercise ordinary modern behavior and the five security regressions.

Unlike the legacy release, this line uses Bundler 2.4.22/RuboCop 1.57, a transitional core matrix, real Rails 7 fixtures and Sidekiq 7 middleware-chain fixtures. PR and release share a reusable validation workflow; framework dependency locks are uploaded as evidence. The old legacy scripts remain historical and cannot validate this gem's Ruby requirement.

The CLI remains lightweight and never boots Rails implicitly. Generator integration uses the same installer. Optional Rails credential boot is deferred to the distinct modern plan. No protocol/schema change, hard-mode activation or SaaS rollout is included. See [readiness](../release-1.2.2-readiness.md) for observed results and pending gates.

Local verification passed the six core runtimes, eight combined Rails/Sidekiq application pairs and six standalone Sidekiq middleware pairs, plus the audit and release-readiness execution gates. Remaining external/approval gates and evidence limitations are recorded in readiness; no compatibility status or published capability is promoted implicitly.
