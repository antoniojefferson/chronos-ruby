# Compatibility

Chronos Ruby 0.x is the legacy line. Technical compatibility does not make an end-of-life Ruby or Rails release secure.

| Ruby | Rails integration | Status | Evidence |
|---|---|---|---|
| 2.2.10 | None in 0.1 | Best effort | Local unit, contract, integration, fork, and fake-server suite |
| 2.3.8 | None in 0.1 | Best effort | Dedicated CI job pending first successful run |
| 2.4.10 | None in 0.1 | Best effort | Dedicated CI job pending first successful run |
| 2.5.9 | None in 0.1 | Best effort | Dedicated CI job pending first successful run |
| 2.6.10 | None in 0.1 | Best effort | Dedicated CI job pending first successful run |
| 2.7 and newer | None in 0.x | Unsupported | Belongs to transitional or modern lines |

No Rails version is declared supported by version 0.1. Rails applications may call the plain Ruby API manually. Rails support requires a real example application, framework integration tests, and a successful dedicated matrix job.

Status meanings:

- Supported: the complete required compatibility gate passes.
- Best effort: intended to work, but the complete gate has not passed yet.
- Deprecated: still tested while removal is planned.
- Unsupported: outside this release line.
