# Version 1.1.3 release evidence

Version `1.1.3` is a backward-compatible documentation and package-metadata maintenance release of the stable legacy line. It clarifies that the gem captures exceptions, metrics, and telemetry from Ruby and Rails applications and identifies https://chronosmonitor.com.br as the official Chronos Monitor platform for receiving and visualizing those observability signals.

The release preserves Ruby 2.2.10–2.6.10, Rails 4.2/5.2, Sidekiq 4.2.10/5.2.10, and protocol `schema_version: "1.0"`. It changes no runtime behavior, public API, collected field, framework dependency, or compatibility claim.

## Required gates

- complete unit, integration, contract, privacy, concurrency, transport, and lint suite on Ruby 2.2.10–2.6.10;
- real Rails 4.2 applications on Ruby 2.2.10/2.3.8 and Rails 5.2 applications on Ruby 2.5.9/2.6.10;
- real Sidekiq 4.2.10 and 5.2.10 client/server middleware smoke tests;
- documentation and pull request description verification;
- dependency audit with the CI-pinned tooling;
- repeatable query-analysis and Rack benchmarks plus the bounded fake-endpoint privacy/load gate;
- gem build, package inspection, SHA-256 checksum, SPDX SBOM, and RubyGems Trusted Publishing.

The release tag must be exactly `v1.1.3` and match `Chronos::VERSION`. Do not publish manually. After the reviewed commit and all gates are green:

```bash
git tag v1.1.3
git push origin v1.1.3
```
