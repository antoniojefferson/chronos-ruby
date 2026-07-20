# Troubleshooting

## Configuration raises an error

Verify `project_id`, `project_key`, and `host`. HTTPS is required while `ssl_verify` is true. Queue size, worker count, payload size, and timeouts must be positive.

## `Chronos.notify` returns false

The agent may be unconfigured, disabled, ignored in the current environment, unable to serialize the value, closed, or at queue capacity. Check the configured logger and `agent.diagnostics` when constructing an agent directly in diagnostics code.

## `Chronos.notify_sync` returns false

Check DNS, TLS certificates, credentials, HTTP status, proxy configuration, and timeout values. Version 0.2 does not retry.

## Events disappear during shutdown

Call `Chronos.close(timeout)` and inspect its Boolean result. A `false` result means accepted work could not finish before the timeout.

## Forking servers

Workers are recreated after a process fork. Configure before or after forking, then call capture in the child. Always close each child during shutdown.

## Sensitive data

Stop sending the affected field, rotate exposed credentials, and follow the incident process for the Chronos SaaS. Add the application-specific key to `blocklist_keys`, create a privacy contract fixture, and repeat the local payload audit. Pattern detection is defensive and cannot recognize every domain-specific identifier.
