# Rails 5.2 compatibility application

This minimal application exercises a normal request, controller exception, SQL, view rendering, cache, Active Job, Action Mailer, parameter filtering, flush, and shutdown.

```bash
BUNDLE_GEMFILE=examples/rails-5.2/Gemfile bundle _1.17.3_ install
BUNDLE_GEMFILE=examples/rails-5.2/Gemfile bundle _1.17.3_ exec ruby examples/rails-5.2/script/smoke
```

Its fallback endpoint is intentionally unavailable. Supply a local fake Chronos server through `CHRONOS_HOST` when validating delivered payloads.
