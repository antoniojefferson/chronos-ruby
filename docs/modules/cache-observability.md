# Cache observability

Rails ActiveSupport cache notifications produce individual bounded `cache` events containing operation, duration, hit/miss outcome, backend, and namespace. When a trace is active, duration also contributes to the request's cache breakdown.

Raw cache keys and values are never delivered. The default `cache_key_mode = :none` omits key identity entirely. Applications that need correlation can opt into a project-scoped SHA-256 value:

```ruby
Chronos.configure do |config|
  # connection settings omitted
  config.cache_key_mode = :sha256
end
```

Hashing accepts at most 2,048 bytes of key text and emits a fixed 64-character hexadecimal value. It is pseudonymization rather than anonymization: an attacker who can guess a low-entropy key may reproduce candidate hashes when project scope is known. Do not encode credentials or unnecessary personal data in cache keys.

The normalizer never calls cache read/write APIs, inspects cached values, or retains keys. Unsupported or incomplete notification payloads become an `unknown` outcome without raising into Rails.
