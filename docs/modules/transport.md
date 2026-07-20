# Transport module

`Chronos::Ports::Transport` defines delivery behavior. `Chronos::Adapters::NetHttpTransport` implements it with the Ruby standard library.

Each event uses bounded open and read timeouts. TLS verification is enabled by default. Authentication and idempotency values are headers. Redirects are not followed. Statuses are classified as success, request timeout, client error, rate limited, server error, network error, or closed. HTTP `408`, `429`, `5xx`, and network failures are retryable; other `4xx` responses are permanent.

The adapter creates a connection per event in version 0.3. This is conservative for legacy applications and avoids shared socket lifecycle state. Retry remains in `DeliveryPipeline`, behind the transport port.

A successful response may contain `X-Chronos-Remote-Configuration`. The adapter rejects the header when it exceeds `remote_config_max_bytes` or is not a JSON object. It never interprets policy or accepts remote endpoint and credential changes; that allowlist belongs to `RemoteConfiguration`.

Risks include proxy credential exposure, TLS incompatibility on old operating systems, endpoint latency, and stale remote policy until another response arrives. Tests use a local fake HTTP server to verify headers, `2xx`, `408`, `429`, `500`, timeout, invalid TLS, and bounded remote policy parsing.
