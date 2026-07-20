# Compatibility

Chronos Ruby 0.x is the legacy line. Technical compatibility does not make an end-of-life Ruby or Rails release secure.

| Ruby | Rails integration | Status | Evidence |
|---|---|---|---|
| 2.2.10 | Rails 4.2 | Best effort | Core CI, Rails 4.2 example, dedicated smoke gate |
| 2.3.8 | Rails 4.2 / 5.0 | Best effort | Core CI and feature-detection contract; dedicated app gate incomplete |
| 2.4.10 | Rails 4.2 / 5.0 | Best effort | Core CI and feature-detection contract; dedicated app gate incomplete |
| 2.5.9 | Rails 5.2 | Best effort | Core CI, Rails 5.2 example, dedicated smoke gate |
| 2.6.10 | Rails 5.2 | Best effort | Core CI and feature-detection contract; dedicated app gate incomplete |
| 2.7 and newer | None in 0.x | Unsupported | Belongs to transitional or modern lines |

Version 0.5 includes Rails 4.2 and 5.2 applications plus a dedicated matrix, but this document conservatively keeps the combinations at `Best effort` until all release-gate evidence, including fake-server payload validation, is green. Rails 5.0 uses the same feature-detected public APIs but does not yet have its own example application.

Status meanings:

- Supported: the complete required compatibility gate passes.
- Best effort: intended to work, but the complete gate has not passed yet.
- Deprecated: still tested while removal is planned.
- Unsupported: outside this release line.
