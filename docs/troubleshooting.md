# Troubleshooting

## Configuration raises an error

Verify `project_id`, `project_key`, and `host`. HTTPS is required while `ssl_verify` is true. Queue size, worker count, payload size, breadcrumb capacity, and timeouts must be positive. `breadcrumb_max_bytes` must be at least 128.

## `Chronos.notify` returns false

The agent may be unconfigured, disabled, ignored in the current environment, unable to serialize the value, closed, or at queue capacity. Check the configured logger and `agent.diagnostics` when constructing an agent directly in diagnostics code.

## `Chronos.notify_sync` returns false

Check DNS, TLS certificates, credentials, HTTP status, proxy configuration, and timeout values. The resilience layer retries only network errors, HTTP `408`, `429`, and `5xx` responses. Inspect `agent.diagnostics` when constructing an agent directly to see retry state, backlog usage, and the circuit state.

## Rack exception is not captured

Confirm that `Chronos.configure` runs before the middleware handles requests and that the middleware wraps the application component that raises. Version 0.4 captures exceptions raised by the initial downstream Rack call; an exception raised later while a server enumerates a streaming response body is outside this release. The original exception is always re-raised, so the server log should still show it.

## Context appears missing

The legacy context store is thread-local. A new application-created thread does not inherit context. Establish a new `Chronos.with_context` scope inside that thread, and issue manual notification before the scope exits. For Rack capture, supply user and explicit parameters through the documented environment keys.

## Events disappear during shutdown

Call `Chronos.close(timeout)` and inspect its Boolean result. A `false` result means accepted work could not finish before the timeout.

## Forking servers

Workers are recreated after a process fork. Configure before or after forking, then call capture in the child. Always close each child during shutdown.

## Sensitive data

Stop sending the affected field, rotate exposed credentials, and follow the incident process for the Chronos SaaS. Add the application-specific key to `blocklist_keys`, create a privacy contract fixture, and repeat the local payload audit. Pattern detection is defensive and cannot recognize every domain-specific identifier.
