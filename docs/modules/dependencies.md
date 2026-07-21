# Dependency inventory

Version `0.8.0.pre.1` emits a separate `dependencies` event at most once per configured agent. It is queued before the first capture or during explicit flush/close and is never attached to each exception.

The inventory contains Ruby version/engine/platform, bounded names and versions from already loaded gem specs, the configured `app_version` release identifier, and Rails, Sidekiq, web server, or database adapter labels when safely detectable. The agent does not parse `Gemfile.lock`, activate missing gems, inspect gem paths/source, scan environment variables, open a database connection, or collect dependency configuration.

```ruby
Chronos.configure do |config|
  # connection settings omitted
  config.dependency_reporting = true
  config.dependency_max_items = 100
end

# Optional after application boot, before the first regular event:
Chronos.report_dependencies
```

`dependency_max_items` accepts 1–200 and defaults to 100. Entries are sorted by name before truncation so repeated boots are stable. Set `dependency_reporting = false` when inventory collection is unnecessary or prohibited. Because collection is once-only, gems loaded after the first event appear only after a new agent configuration or process boot.
