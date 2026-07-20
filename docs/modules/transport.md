# Transport module

`Chronos::Ports::Transport` defines delivery behavior. `Chronos::Adapters::NetHttpTransport` implements it with the Ruby standard library.

Each event uses bounded open and read timeouts. TLS verification is enabled by default. Authentication and idempotency values are headers. Redirects are not followed. Statuses are classified as success, client error, rate limited, server error, network error, or closed.

The adapter creates a connection per event in version 0.2. This is conservative for legacy applications and avoids shared socket lifecycle state. Batch optimization and retry may be added behind the same port.

Risks include proxy credential exposure, TLS incompatibility on old operating systems, and endpoint latency. Tests use a local fake HTTP server to verify headers, `2xx`, `429`, `500`, timeout, and invalid TLS behavior.
