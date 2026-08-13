# Version 1.1.2 release evidence

Version `1.1.2` is a backward-compatible maintenance release of the stable legacy line. It simplifies the generated Rails initializer, keeps the official host internal, derives a default Rails service name, preserves application ownership of the logger, and automatically installs the existing optional Sidekiq 4/5 middleware in Rails applications.

The release preserves Ruby 2.2.10–2.6.10, Rails 4.2/5.2, Sidekiq 4.2.10/5.2.10, and protocol `schema_version: "1.0"`. It introduces no mandatory framework dependency and no transitional 1.2-only API.

## Required gates

- complete unit, integration, contract, privacy, concurrency, transport, and lint suite on Ruby 2.2.10–2.6.10;
- real Rails 4.2 applications on Ruby 2.2.10/2.3.8 and Rails 5.2 applications on Ruby 2.5.9/2.6.10;
- real Sidekiq 4.2.10 and 5.2.10 client/server middleware smoke tests;
- generated initializer boot, service-name fallback, logger mutability, optional Sidekiq installation, and idempotency tests;
- documentation verification, repeatable benchmarks, and the bounded fake-endpoint privacy/load gate;
- gem build, package inspection, SHA-256 checksum, SPDX SBOM, and RubyGems Trusted Publishing.

The release tag must be exactly `v1.1.2` and match `Chronos::VERSION`. Do not publish manually. After the reviewed commit and all gates are green:

```bash
git tag v1.1.2
git push origin v1.1.2
```
