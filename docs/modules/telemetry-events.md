# Framework telemetry events

`Chronos::Core::TelemetryEvent` and `Chronos::Core::TelemetrySerializer` extend the v1 envelope to `request`, `query`, `job`, `cache`, `external_http`, `dependencies`, and `metric_batch` events. These values exist so integrations do not model operational telemetry as fake exceptions.

Telemetry has the same `schema_version`, event ID, timestamps, project, environment, service, runtime, context, sanitization, payload-size limit, idempotency header, asynchronous queue, retry, circuit breaker, and memory backlog used by exception events. Unsupported types are rejected locally.

`Chronos.record_event` is the narrow integration entry point. Application code should prefer documented higher-level APIs; its payload is allowlisted by each bundled integration and then sanitized. Remote configuration can reduce or disable any locally enabled telemetry type but cannot enable a type excluded by local configuration.

Version 0.8 aggregates request, query, job, and enabled external HTTP observations into `metric_batch` events by default. Cache remains an individual event while contributing to an existing traced request breakdown. Dependencies use one separate event per agent. Set `apm_enabled = false` only when individual legacy telemetry is required for diagnostics. Percentiles remain server-side; see [Essential APM aggregation](apm-aggregation.md).
