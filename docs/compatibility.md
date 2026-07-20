# Compatibility

Chronos Ruby 0.x is the legacy line. Technical compatibility does not make an end-of-life Ruby or Rails release secure.

| Ruby | Rails integration | Status | Evidence |
|---|---|---|---|
| 2.2.10 | Rack protocol in 0.4; no Rails | Best effort | Dedicated legacy core CI and Rack contract tests |
| 2.3.8 | Rack protocol in 0.4; no Rails | Best effort | Dedicated legacy core CI and Rack contract tests |
| 2.4.10 | Rack protocol in 0.4; no Rails | Best effort | Dedicated legacy core CI and Rack contract tests |
| 2.5.9 | Rack protocol in 0.4; no Rails | Best effort | Dedicated legacy core CI and Rack contract tests |
| 2.6.10 | Rack protocol in 0.4; no Rails | Best effort | Dedicated legacy core CI and Rack contract tests |
| 2.7 and newer | None in 0.x | Unsupported | Belongs to transitional or modern lines |

No Rails version is declared supported by version 0.4. The middleware is tested against the Rack protocol shape without adding a Rack runtime dependency. Rails support requires a real example application, Railtie integration tests, and a successful dedicated matrix job.

Status meanings:

- Supported: the complete required compatibility gate passes.
- Best effort: intended to work, but the complete gate has not passed yet.
- Deprecated: still tested while removal is planned.
- Unsupported: outside this release line.
