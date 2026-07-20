# Architecture

Chronos Ruby 0.4 uses hexagonal boundaries so the legacy core remains independent of frameworks and delivery infrastructure.

```mermaid
flowchart TB
  Facade[Chronos facade] --> Application[Application / CaptureException]
  Application --> Core[Core / Notice and serialization]
  Application --> Ports[Ports / Transport contract]
  Ports --> Adapter[Adapters / NetHttpTransport]
  Application --> Delivery[Application / DeliveryPipeline]
  Delivery --> Internal[Internal / BoundedQueue, WorkerPool, and MemoryBacklog]
  Internal --> Ports
  Rack[Integrations / Rack middleware] --> Facade
  Facade --> Context[Ports / ContextStore]
  Context --> ThreadLocal[Adapters / ThreadLocalContextStore]
```

## Boundaries

- Domain/Core owns immutable event values and Ruby normalization.
- Application owns use-case ordering and failure containment.
- Ports define behavior expected from transport and execution-context infrastructure.
- Adapters contain Net::HTTP, TLS, and thread-local context behavior.
- Internal contains private concurrency and diagnostic mechanisms.
- Integrations contain optional framework entry points and never enter the domain boundary.

The `Chronos` module is a thin facade. Rails, Rack, ActiveSupport, Sidekiq, and job libraries must not be required by the core.

## Rack capture flow

The Rack middleware establishes a context-store scope, adds a bounded request breadcrumb, and calls the downstream application. An unhandled exception is enriched with request duration and status, captured through the normal notice pipeline, then re-raised unchanged. The context-store adapter restores or clears its value in `ensure`. The middleware implements the Rack protocol without requiring the Rack library.

## Capture flow

An exception becomes an immutable notice. `Sanitizer` removes sensitive values before `SafeSerializer` creates a bounded JSON envelope. Asynchronous capture inserts only that sanitized serialized event into the queue. A fixed worker sends it through `DeliveryPipeline`, which applies finite retry, a circuit breaker, and a fixed memory backlog. Synchronous capture bypasses the queue but uses the same privacy and resilience boundaries.

## Failure policy

Explicit invalid configuration raises `Chronos::ConfigurationError`. Capture, serialization, logger, worker, retry, circuit, TLS, network, HTTP, and remote-policy failures do not escape into the host application. They produce `false`, a classified transport result, a bounded state transition, or a bounded logger diagnostic.
