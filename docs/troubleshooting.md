# Troubleshooting

## Configuration raises an error

Verify `project_id`, `project_key`, and `host`. HTTPS is required while `ssl_verify` is true. Queue size, worker count, payload size, breadcrumb capacity, and timeouts must be positive. `breadcrumb_max_bytes` must be at least 128.

## `Chronos.notify` returns false

The agent may be unconfigured, disabled, ignored in the current environment, unable to serialize the value, closed, or at queue capacity. Check the configured logger and `agent.diagnostics` when constructing an agent directly in diagnostics code.

## `Chronos.notify_sync` returns false

Check DNS, TLS certificates, credentials, HTTP status, proxy configuration, and timeout values. The resilience layer retries only network errors, HTTP `408`, `429`, and `5xx` responses. Inspect `agent.diagnostics` when constructing an agent directly to see retry state, backlog usage, and the circuit state.

## Rack exception is not captured

Confirm that `Chronos.configure` runs before the middleware handles requests and that the middleware wraps the application component that raises. Version 0.5 captures exceptions raised by the initial downstream Rack call; an exception raised later while a server enumerates a streaming response body is outside this release. The original exception is always re-raised, so the server log should still show it.

## Rails middleware or telemetry is missing

Require `chronos/rails` from the generated initializer and confirm it runs before requests. Automatic integration is disabled by default in Rails test and console; set `rails_capture_in_test` or `rails_capture_in_console` explicitly when validating those environments. `rails_enabled = false` disables all automatic Rails hooks. Active Job is subscribed only when its constant is available during installation.

## Rails telemetry contains no SQL or cache key

This is intentional. Version 0.5 records SQL operation name/duration and cache operation/store/hit status without raw statements, binds, keys, or values. These omissions are privacy and cardinality boundaries, not capture failures.

## Sidekiq telemetry is missing

Require `chronos/sidekiq` after Sidekiq is available and configure Chronos before jobs run. The entry point uses Sidekiq's public client/server middleware configuration and remains optional. Requiring only `chronos` or `chronos/rails` does not load Sidekiq. A job already enqueued before client middleware installation may lack propagated trace context, but server timing and failure capture can still run.

## A failed Sidekiq job appears twice

The bundled middleware does not install a global error handler and uses `notify_once` inside a shared job scope. Check for application-installed Chronos calls or third-party global handlers outside that scope. Keep a single bundled server middleware entry in the Sidekiq chain.

## Context appears missing

The legacy context store is thread-local. A new application-created thread does not inherit context. Establish a new `Chronos.with_context` scope inside that thread, and issue manual notification before the scope exits. For Rack capture, supply user and explicit parameters through the documented environment keys.

## Events disappear during shutdown

Call `Chronos.close(timeout)` and inspect its Boolean result. A `false` result means accepted work could not finish before the timeout.

## Forking servers

Workers are recreated after a process fork. Configure before or after forking, then call capture in the child. Always close each child during shutdown.

## Sensitive data

Stop sending the affected field, rotate exposed credentials, and follow the incident process for the Chronos SaaS. Add the application-specific key to `blocklist_keys`, create a privacy contract fixture, and repeat the local payload audit. Pattern detection is defensive and cannot recognize every domain-specific identifier.
