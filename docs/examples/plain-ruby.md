# Plain Ruby example

Set test project credentials and an endpoint, then run the executable example:

```bash
CHRONOS_PROJECT_ID=project-id \
CHRONOS_PROJECT_KEY=project-key \
CHRONOS_HOST=https://chronos.example.com \
bundle _1.17.3_ exec ruby examples/plain-ruby/example.rb
```

The example reports one manual exception and closes the agent with a two-second timeout. Use a local fake endpoint when auditing the payload.

For a network-free privacy audit, run:

```bash
bundle _1.17.3_ exec ruby examples/plain-ruby/privacy_audit.rb
```

For a network-free outage and bounded-backlog example, run:

```bash
bundle _1.17.3_ exec ruby examples/plain-ruby/resilient_delivery.rb
```

For network-free per-instance outbound HTTP instrumentation, run:

```bash
bundle _1.17.3_ exec ruby examples/plain-ruby/external_http.rb
```

The examples demonstrate final event construction, key redaction, e-mail and Bearer-token detection, application-specific blocklisting, identifier hashing, and the bounded external HTTP payload without opening a socket.
