# Remote configuration module

## Problem

Operators may need to reduce event volume or stop collection during an incident without redeploying a legacy application. Accepting unrestricted server instructions would create remote-code, SSRF, credential, privacy, and memory risks.

## Boundary

`NetHttpTransport` only parses a bounded JSON object from the `X-Chronos-Remote-Configuration` success-response header. `Chronos::Application::RemoteConfiguration` owns the allowlist and local upper bounds. `DeliveryPipeline` applies accepted policy to later capture and delivery work.

## Allowed fields

| Field | Accepted value | Local restriction |
|---|---|---|
| `sampling_rate` | Number from `0.0` to `1.0` | Cannot exceed local `sampling_rate` |
| `enabled_event_types` | Array of strings | Intersected with local and implemented event types |
| `max_payload_size` | Integer | Cannot exceed local maximum or fall below 256 bytes |
| `ignored_fingerprints` | Up to 100 strings | Exact matching only; 256 bytes per value |
| `send_interval` | Non-negative seconds | Cannot exceed `max_remote_send_interval` |
| `kill_switch` | Boolean | Stops later capture while active |

Unknown keys are ignored. If a recognized value is invalid, the document is rejected atomically and the previous policy remains active.

## Explicitly forbidden

Remote configuration cannot change host, proxy, project ID, project key, TLS verification, logger, queue or backlog capacity, retry limits, local upper bounds, Ruby code, object serialization, regular expressions, or arbitrary headers. No `eval`, `send`, `Marshal`, YAML, or application callback is used.

## Example server response

```text
HTTP/1.1 202 Accepted
X-Chronos-Remote-Configuration: {"sampling_rate":0.25,"send_interval":1.0,"kill_switch":false}
```

Disable this channel locally when it is not required:

```ruby
Chronos.configure do |config|
  # connection settings omitted
  config.remote_configuration = false
end
```

## Risks and limits

- The policy is process-local and is not persisted across restarts.
- A stale policy remains until another accepted response changes it.
- The header size is bounded before JSON parsing, but upstream proxies may impose a lower header limit.
- Sampling uses process-local randomness and is not a globally exact rate.
- Version 0.3 does not poll a separate configuration endpoint.

## Tests

Tests cover the field allowlist, local caps, unsupported event types, invalid types, regex rejection, forbidden endpoint and credential keys, response-header byte limits, kill switch, sampling, and atomic preservation of previous state.
