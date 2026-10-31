# Version 1.2.2 release preparation

This release ports packaged deployment automation and the five security corrections from legacy 1.1.4 into the transitional Ruby >= 2.7 and < 3.5 line. It preserves the main-line integrations and protocol v1. It does not introduce Ruby 4, Rails 8, or the planned 2.x line.

The gates include core/security/lint, standalone CLI/adapters, real Rails 7 applications, real Sidekiq 7 middleware chains, installed-package tests, documentation, audit, benchmarks, and maintainer approval. Local execution evidence is recorded below as verification proceeds; a configured workflow is not proof of success.

Rails fixtures pin railties/actionpack/activejob/activerecord 7.0.10, 7.1.6 and 7.2.4. Sidekiq is pinned to 7.3.10. Official RubyGems metadata reports Ruby >= 2.7 for Rails 7.0/7.1 and Sidekiq 7.3.10, and >= 3.1 for Rails 7.2.4. See [Rails requirements](https://guides.rubyonrails.org/v7.2.0/upgrading_ruby_on_rails.html#ruby-versions), [Rails 7.2.4 metadata](https://rubygems.org/gems/rails/versions/7.2.4), and [Sidekiq metadata](https://rubygems.org/gems/sidekiq/versions/7.3.10).

The Sidekiq smoke exercises its actual public middleware chains, context, preserved arguments, and error propagation; it does not start Redis or a worker process. The Rails smoke boots a real app with SQLite, controller/SQL notifications, Active Job, Error Reporter deduplication and the deploy generator. The in-memory test transport prevents SaaS requests.

Do not promote any Best effort combination solely because these focused smokes pass. SaaS receipts, ingestion/ledger/projection, authorized provider execution, Redis-backed worker lifecycle, dependency audit, load/benchmark gates and remote CI retain their own evidence requirements.

No tag or publication is authorized by preparation. After approval and green gates, only tag `v1.2.2`, matching Chronos::VERSION, triggers the protected Trusted Publishing workflow. Never replace a previously published artifact. The SaaS must select CLI recipes by explicitly supported release ranges per line and retain scripts for older clients.

## Local execution evidence

The reviewed main-line integration implementations remain intact; the adapted port passed the following local Linux/amd64 gates:

- MRI 2.7.8, 3.0.7, 3.1.7, 3.2.11, 3.3.13 and 3.4.12: 227 RSpec examples (including modern integration and security regressions), RuboCop 1.57.2 with 241 files and no offenses, and 25 standalone tests with 127 assertions per runtime.
- Built artifact installation, HTTPS receipt/notification checks, safe integration generation, and an isolated Bundler frozen client verifying the loaded gem path. The HTTPS suite runs directly and through a Bundler-generated binstub.
- All eight Rails pairs in compatibility.md, now including automatic Sidekiq installation in the actual app: single initialization/request capture, SQL privacy, Active Job, genuine Error Reporter capture/deduplication and deploy generator namespace/idempotence/state.
- Standalone Sidekiq 7.3.10 configuration/middleware chains on all six Rubies. Actual failure re-raising is asserted; Redis/worker lifecycle is not exercised.
- Bundler Audit 0.9.1 on Ruby 3.3.13 core dependencies: no vulnerabilities found against ruby-advisory-db commit 92c25ce091b117bfe9ac54a5bbb0877356e9de7f (1290 advisories). This does not certify consumer/framework/stdlib graphs or EOL runtimes.
- Query-analysis benchmark (10000 iterations/1000 warmup), Rack comparison (10000 iterations/1000 warmup/5 samples), and fake-endpoint load/privacy (500 received of 500 events) passed. Measurements under emulation/concurrent tests are not production performance claims.
- Gem construction, SHA-256 calculation, SPDX SBOM (25 loaded build-environment packages), documentation/PR validation, workflow YAML and README shell syntax checks passed. The SBOM is build-environment evidence, not a complete inventory of native OS dependencies.

Local test containers are disposable; no customer or host Gemfile.lock was modified. Remote CI, provider/SaaS validation, Redis-backed lifecycle and final approval remain open. No tag was created and no package was published.
