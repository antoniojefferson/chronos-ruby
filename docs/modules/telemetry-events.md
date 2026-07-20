# Framework telemetry events

`Chronos::Core::TelemetryEvent` and `Chronos::Core::TelemetrySerializer` extend the v1 envelope to `request`, `query`, `job`, and `cache` events. These values exist so framework adapters do not model operational timings as fake exceptions.

Telemetry has the same `schema_version`, event ID, timestamps, project, environment, service, runtime, context, sanitization, payload-size limit, idempotency header, asynchronous queue, retry, circuit breaker, and memory backlog used by exception events. Unsupported types are rejected locally.

`Chronos.record_event` is the narrow integration entry point. Application code should prefer documented higher-level APIs; its payload is allowlisted by each bundled integration and then sanitized. Remote configuration can reduce or disable any locally enabled telemetry type but cannot enable a type excluded by local configuration.

Version 0.5 intentionally sends individual framework events. Aggregation, percentiles, slow-query analysis, and transaction breakdowns remain part of version 0.7.
