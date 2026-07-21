# Bounded local ignore rules

Configure startup rules with `config.ignore_rules` or add a rule to the active agent with `Chronos.ignore_if`. A rule receives an immutable normalized notice and must return exactly `true` to discard it before serialization, queueing, retry, or network work.

```ruby
Chronos.ignore_if do |notice|
  notice.exception_class == "SomeExpectedError"
end
```

At most `max_ignore_rules` rules are retained (default 20, hard maximum 100). Registration returns `false` when Chronos is not configured, the object is not callable, or the limit is full. A rule failure is contained and treated as no match. Rules run in the capture caller and therefore must be fast, thread-safe, and free of I/O. Remote configuration cannot add executable rules.
