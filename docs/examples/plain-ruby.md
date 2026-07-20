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

The example builds the final event locally and demonstrates key redaction, e-mail and Bearer-token detection, application-specific blocklisting, and identifier hashing.
