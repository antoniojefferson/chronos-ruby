# Rails 4.2 and 5.2 legacy integration

Version 0.5 adds an explicit Rails entry point:

```ruby
require "chronos/rails"
```

`Chronos::Rails::Railtie` registers one initializer after `load_config_initializers`. It requires no Zeitwerk and delegates to an idempotent installer. The installer uses feature detection, installs `Chronos::Integrations::Rack::Middleware` once per application, and registers notification subscribers once per `ActiveSupport::Notifications` bus.

## Installation generator

Run:

```bash
rails generate chronos:install
```

The generator creates `config/initializers/chronos.rb`. The template reads only explicitly named `CHRONOS_*` variables, uses `Rails.env`, adopts `Rails.logger` when available, and disables automatic integration in test and console by default. It invokes the idempotent installer as a fallback for applications that disabled Bundler auto-require, so the Railtie and initializer paths cannot create duplicate hooks. It never scans all environment variables or modifies routes and application classes.

## Captured integrations

The public `ActiveSupport::Notifications.subscribe` API is used for:

| Notification | Chronos event | Allowlisted data |
|---|---|---|
| `process_action.action_controller` | `request` | controller, action, status, method, query-free path, normalized route, duration, sanitized parameters |
| `render_template.action_view` | `request` with `kind=view` | template basename and duration |
| `sql.active_record` | `query` | operation name, cached flag, and duration |
| `deliver.action_mailer` | `job` with `kind=mailer` | mailer, action, and duration |
| `perform.active_job` | `job` | job class, queue, and duration, when Active Job is available |
| cache read/write/hit notifications | `cache` | operation, store, hit flag, and duration |

Raw SQL, binds, cache keys, mail recipients and bodies, job IDs and arguments, request/response bodies, cookies, and authorization headers are not copied. Template identifiers are reduced to their basename. Every event passes through `Sanitizer`, `SafeSerializer`, the bounded queue, retry policy, circuit breaker, and memory backlog.

## Controller exceptions and deduplication

When `process_action.action_controller` exposes `exception_object`, the original exception is captured. Rails versions that expose only the public exception tuple produce a bounded synthetic `RuntimeError` containing the supplied message. A request-scoped deduplicator prevents the same error from being reported again by the Rack middleware. The host application continues to receive its original exception semantics.

## Configuration

```ruby
Chronos.configure do |config|
  # connection settings omitted
  config.rails_enabled = true
  config.rails_capture_in_test = false
  config.rails_capture_in_console = false
  config.rails_capture_user_agent = false
end
```

Setting `rails_enabled = false` prevents middleware and subscribers from being installed. Test and console switches affect only automatic Rails integration; explicit manual Chronos calls retain their normal configuration behavior.

## Compatibility evidence

The repository contains independent applications under `examples/rails-4.2` and `examples/rails-5.2`. Their smoke scripts execute a successful request, controller exception, SQL query, view, cache access, inline Active Job, Action Mailer, flush, and shutdown. The dedicated legacy Rails workflow is the release gate; a framework/runtime pair must not be labeled `Supported` until that job and fake-server payload validation pass.

## Limits

Version 0.5 emits individual bounded timings. It does not aggregate APM metrics, capture SQL text, or calculate query fingerprints. Sidekiq support is a separate optional integration beginning in version 0.6; full Active Job propagation remains a later 0.6 increment.
