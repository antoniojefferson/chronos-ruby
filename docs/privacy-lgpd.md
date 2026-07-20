# Privacy and LGPD

Version 0.5 sanitizes exception and framework telemetry before JSON serialization, queueing, retry backlog, or transport. This reduces accidental exposure, but the host application remains responsible for lawful purpose, minimization, access control, retention, and responses to data-subject requests.

## Default policy

| Data | Default behavior |
|---|---|
| Keys such as `password`, `secret`, `token`, `authorization`, `cookie`, `session`, `card_number`, `cpf`, and `cnpj` | Replaced with `[FILTERED]` |
| Bearer tokens and JWT-like strings | Replaced in free text |
| E-mail addresses | Replaced with `[FILTERED_EMAIL]` |
| CPF and CNPJ candidates with valid check digits | Replaced with `[FILTERED_DOCUMENT]` |
| Payment-card candidates that pass the Luhn check | Replaced with `[FILTERED_CARD]` |
| IPv4 addresses | Last octet replaced with `0` |
| Unknown Ruby objects | Represented by class name without calling application serialization |
| Request/response bodies, raw query strings, cookies, authorization headers, raw SQL/binds, cache values, mail bodies, job arguments, environment variables | Never collected automatically in version 0.5 |

The retry backlog exists only in process memory, accepts only `SerializedEvent`, has a fixed capacity, and disappears on process exit. Version 0.5 does not persist telemetry to disk.

## Rails telemetry

Rails subscribers use per-notification allowlists. SQL events retain only the operation name, cached flag, and duration; cache events omit key and value; mailer events omit addresses and content; Active Job events omit job ID and arguments; view identifiers are reduced to basenames. Controller parameters are sanitized by the normal payload pipeline before queueing.

## Rack context and breadcrumbs

The Rack middleware copies only bounded operational fields and parameter hashes that another component already parsed. It does not read `rack.input` or copy `QUERY_STRING`. User context is opt-in through `chronos.user`, and user agent collection is disabled unless the middleware option enables it.

Breadcrumbs contain category, bounded message, bounded metadata, and timestamp. No raw request, response, SQL, cache, job, log, or external HTTP payload is added automatically. Rack context and breadcrumbs pass through the same sanitizer as manual context before queueing.

Blocklist matching accepts `String`, `Symbol`, and `Regexp`. String and Symbol matching is case-insensitive after punctuation normalization and also protects namespaced keys such as `user_password`.

## Configuration

```ruby
Chronos.configure do |config|
  # required connection settings omitted
  config.blocklist_keys += [:medical_record, /bank_account/i]
  config.allowlist_keys += [:authorization_state]
  config.hash_keys += [:customer_id]
  config.anonymize_ip = true

  config.filters << proc do |key, value|
    key.to_s == "internal_reference" ? "[REMOVED]" : value
  end
end
```

An allowlisted key bypasses only key-name redaction. Content detection remains active, so an allowlisted field containing a Bearer token or e-mail address is still filtered. Identifier hashing uses SHA-256 scoped by the public project identifier. It is irreversible output, but low-entropy identifiers may still be guessable and should not be treated as anonymized data.

Custom filters receive the key and already sanitized value. If a filter raises, that field becomes `[FILTERED]`; the error does not escape into the host application.

## Health applications

Do not send diagnoses, exam results, prescriptions, patient names, or free-form clinical notes. Use a scoped opaque identifier only when it is necessary and authorized:

```ruby
config.blocklist_keys += [:patient_name, :diagnosis, :clinical_notes]
config.hash_keys += [:patient_id]

Chronos.notify(error, :context => {
  "operation" => "schedule_exam",
  "patient_id" => "internal-opaque-id"
})
```

## Financial applications

Do not send cardholder names, full account identifiers, CVV, authentication tokens, or transaction payloads. Prefer categorical operational context:

```ruby
config.blocklist_keys += [:account_number, :pix_key, :bank_payload]
config.hash_keys += [:customer_id]

Chronos.notify(error, :context => {
  "operation" => "authorize_payment",
  "provider" => "example-gateway",
  "customer_id" => "internal-opaque-id"
})
```

## Payload audit procedure

1. Point `host` to a local fake HTTP server controlled by the development team.
2. Exercise representative exception paths with synthetic sensitive fixtures.
3. Inspect the final JSON body, including exception messages and causes.
4. Search for every fixture value in plaintext.
5. Add missing application keys to `blocklist_keys` and repeat the audit.
6. Keep the audit fixtures synthetic and run the privacy contract in CI.

Run the included local example with:

```bash
bundle _1.17.3_ exec ruby examples/plain-ruby/privacy_audit.rb
```

The output must contain redaction placeholders and must not contain any fixture secret.
