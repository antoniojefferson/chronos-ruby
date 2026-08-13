# Version 1.2 release readiness

Version `1.2.0` promotes the transitional Ruby 2.7–3.4 line to a stable package. It includes Rails 7 integration, Sidekiq 7 middleware, fiber-aware context, optional W3C Trace Context, Rails Error Reporter, Action Cable, Faraday, and coexistence with an application-managed OpenTelemetry SDK. The wire protocol remains `schema_version: "1.0"`.

## Release gates

The `v1.2.0` tag must match `Chronos::VERSION`. The release workflow blocks publishing until all of these jobs succeed:

- the full RSpec and RuboCop suite on Ruby 2.7, 3.0, 3.1, 3.2, 3.3, and 3.4;
- documentation and contract verification through `script/verify_docs`;
- bounded query-analysis and comparative benchmarks;
- the 500-event fake-endpoint delivery and privacy gate;
- a second full suite run on the publishing runtime;
- gem build, SHA-256 checksum, SPDX SBOM generation, and RubyGems Trusted Publishing.

Local release preparation must additionally verify syntax, package contents, version consistency, and a clean generated initializer. Publication is performed only by the protected GitHub Actions environment; do not run `gem push` manually.

## Compatibility claims

A stable gem version and a supported framework/runtime pair are separate claims. Only combinations with complete CI and real-application evidence may be marked `Supported` in [compatibility](compatibility.md). Other intended combinations remain `Best effort` and should be validated in staging before production adoption.

Legacy Ruby 2.2–2.6, Rails 4/5, and Sidekiq 4/5 applications must remain on a compatible 1.0/1.1 release. Version 1.2 requires Ruby `>= 2.7` and `< 3.5`.

## Publishing

After the final commit and all branch checks are green:

```bash
git tag v1.2.0
git push origin v1.2.0
```

After Trusted Publishing completes, verify a clean install and run `chronos:verify_integration` against a non-production project before announcing the release as latest.
