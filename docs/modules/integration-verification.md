# Integration verification

`Chronos.verify_integration` performs an explicit end-to-end check of configuration, credentials, receiver availability, and ingestion acknowledgement. Rails registers `chronos:verify_integration` automatically through the Railtie. The command prints exactly one JSON object and exits nonzero unless verification succeeds.

## Flow and ownership

`Chronos::Application::VerifyIntegration` creates one normal v1 exception envelope, delivers it synchronously through `DeliveryPipeline`, and validates the response. `IntegrationVerificationResult` exposes the immutable, bounded public outcome. `RakeTasks` only loads the application environment, calls the facade, prints JSON, and selects the exit status.

The synthetic event is recognizable without changing the event protocol:

```json
{
  "event_type": "exception",
  "payload": {
    "exception": {"class": "Chronos::IntegrationVerificationError"},
    "tags": ["chronos-integration-verification"],
    "fingerprint": "chronos-integration-verification"
  },
  "context": {
    "integration_verification": {
      "schema_version": "1.0",
      "verification_id": "generated-uuid",
      "kind": "integration_verification",
      "test": true
    }
  }
}
```

Chronos must authenticate before acknowledging the event and must correlate both `verification_id` and the envelope event ID. A `2xx` response alone is insufficient. The accepted response must conform exactly to [`integration-verification-response-v1.schema.json`](../../contracts/integration-verification-response-v1.schema.json):

```json
{
  "schema_version": "1.0",
  "success": true,
  "status": "accepted",
  "verification_id": "generated-uuid",
  "credentials_valid": true,
  "event_received": true,
  "event": {"id": "event-uuid"},
  "project": {"id": "project-id", "name": "Project", "status": "active", "environment": "production"},
  "receiver": {"name": "chronos", "status": "operational", "received_at": "2026-07-22T12:00:00Z"},
  "error": null
}
```

The client rejects missing, mismatched, or additional fields. It copies only the allowlisted project and receiver values and never returns the raw body.

## Result and failure classification

The Ruby result supports `success?`, `to_h`, and `to_json`. Its status is `verified` only after the correlated acknowledgement. Failures use `configuration_invalid`, `invalid_credentials`, `project_inactive`, `receiver_unavailable`, `receiver_internal_error`, `rate_limited`, `request_rejected`, `invalid_response`, or `verification_failed`.

- `401` and untrusted `403` responses become `invalid_credentials` with instructions to create an active project API key and verify the configured identifiers.
- A contractual authenticated `403` response may become `project_inactive`.
- network errors, timeouts, an open circuit, and `502`/`503`/`504` become `receiver_unavailable`.
- other `5xx` responses become `receiver_internal_error`.
- malformed or uncorrelated success responses become `invalid_response`.

Failure output uses local messages and guidance. Server exception messages, stack traces, SQL, paths, classes, credentials, response headers, and architecture details are never copied.

## Usage

In Rails, configure Chronos normally and run `bundle exec rake chronos:verify_integration`. In plain Ruby, require `chronos/rake_tasks` and call `Chronos::RakeTasks.install` from the Rakefile. Programmatic callers can use `Chronos.verify_integration` directly.

Verification is an explicit synchronous diagnostic operation. It bypasses sampling and ignore rules so an operator-requested check cannot silently disappear, but it still uses the configured bounded retry, timeout, TLS, circuit, serializer, and transport protections. The receiver should record it as a verification/audit receipt rather than a production application incident.
