# Version 1.1 release evidence

Version `1.1.0` is a backward-compatible minor release of the stable legacy line. It adds bounded SQL diagnostics, optional read-only database inspection, richer query metrics, and safer trace correlation while keeping `schema_version: "1.0"` and the previously validated Ruby/Rails/Sidekiq support matrix.

## Scope decision

The long-term roadmap associates a transitional 1.x line with Ruby 2.7 and Rails 6. This release does not claim that support: no runtime/framework pair becomes `Supported` without dedicated CI, a real example application, fake-endpoint delivery, shutdown, privacy, and integration evidence. Version 1.1.0 is therefore a SemVer-compatible capability release for the current legacy package; the transitional matrix remains future work.

## Candidate evidence

Local release preparation on 2026-08-05 used Ruby 2.2.10 x86_64 on macOS. The tag workflow must reproduce every supported Linux/container gate before RubyGems publication.

| Gate | Local candidate evidence | Tag enforcement |
|---|---|---|
| Unit, integration, contract and documentation | 195 examples, zero failures | every legacy core job plus publish `rake` |
| Ruby style and legacy syntax | 204 Ruby files, zero RuboCop offenses on Ruby 2.2.10 | every legacy core job plus publish `rake` |
| Query analysis privacy | PostgreSQL/MySQL allowlist specs and final serialized-payload integration test | contract/unit/integration suite |
| Normalized-query benchmark | 10,000 iterations with warmup; database inspection disabled | `release-readiness` |
| Legacy Ruby 2.2.10–2.6.10 | locally exercised on 2.2.10; complete result belongs to tag CI | `legacy-core` matrix |
| Rails 4.2/5.2 applications | no new support claim; complete result belongs to tag CI | `legacy-rails` matrix |
| Sidekiq 4/5 applications | no new support claim; complete result belongs to tag CI | `legacy-sidekiq` matrix |
| Repeatable Rack comparison | executed locally with warmup, five samples, median and MAD | `release-readiness` |
| Fake endpoint load/privacy | 500-event local gate with complete receipt and no secret leakage | `release-readiness` |
| Package metadata | gem version, contents, checksum and SPDX SBOM verified locally | publish job |
| Trusted publication | no local push performed | protected RubyGems environment and OIDC |

## Local measurements

The 2026-08-05 Ruby 2.2.10 preparation run produced:

| Measurement | Result |
|---|---:|
| SQL normalization, 10,000 iterations after 1,000 warmup | 453.981 µs/iteration |
| First bounded static analysis, same fixture | 594.862 µs/iteration |
| Direct Rack median, 10,000 calls × 5 samples | 0.015203 s; MAD 0.000351 s |
| Chronos Rack median, same fixture | 0.454667 s; MAD 0.014678 s |
| Median incremental Rack work | 43.946 µs/request |
| Fake endpoint | 500/500 received, 1.322240 s, 378.15 events/s |

The database-inspection path was not benchmarked because a synthetic adapter would not represent catalog/planner cost. Production opt-in requires an adapter/schema-specific staging measurement.

## Release controls

- the tag must be exactly `v1.1.0` and match `Chronos::VERSION`;
- `publish` depends on the legacy core, Rails, Sidekiq, and release-readiness jobs;
- query inspection is disabled by default and never uses `EXPLAIN ANALYZE` or DDL;
- all new APM v1 properties remain optional in the schema for older consumers;
- artifacts contain the gem, SHA-256 checksum, and SPDX SBOM;
- a failed, skipped, or incomplete supported-matrix job blocks publication.

The local artifact is evidence only. Publication must happen through the tag workflow, not with a manual `gem push`.
