# ADR-013 — Legacy Rails integration through public notifications

## Status

Accepted for version 0.5.

## Context

Rails 4.2 and 5.2 predate Zeitwerk as a universal loader and expose different optional components. Automatic capture must not couple the Ruby core to Rails, duplicate middleware or subscribers during reload, or collect high-risk framework payloads.

## Decision

Load Rails integration explicitly through `chronos/rails`. Use a small Railtie initializer after application configuration, an idempotent installer, and public `ActiveSupport::Notifications.subscribe` callbacks. Detect constants and methods before using optional components. Emit request, query, job, and cache envelopes through the same sanitization and delivery pipeline as exceptions.

Allowlist metadata per notification. Never copy SQL text, binds, cache keys, mail bodies, job arguments, request bodies, response bodies, cookies, or authorization headers. Deduplicate controller and Rack exception hooks within request context.

## Alternatives

ActiveSupport method patching and controller monkey patches were rejected because public notifications cover the required lifecycle with less version risk. Modeling timings as exception breadcrumbs was rejected because successful requests and SQL need independently deliverable metrics. Requiring Rails from the core was rejected because plain Ruby applications must remain framework-independent.

## Positive consequences

The core remains independent, installation is reload-safe, optional components degrade cleanly, and Rails telemetry retains existing privacy and outage boundaries.

## Negative consequences

Legacy notification payloads are less uniform than modern tracing APIs. Individual events add delivery volume until aggregation arrives in version 0.7. Synthetic Rails 4.2 controller exceptions may not retain the original exception class when only the public tuple is available.
