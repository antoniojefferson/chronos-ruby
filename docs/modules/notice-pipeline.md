# Notice pipeline

The notice pipeline converts a Ruby `Exception` into a versioned JSON event.

```mermaid
flowchart LR
  Exception --> NoticeBuilder
  NoticeBuilder --> BacktraceParser
  NoticeBuilder --> CauseCollector
  NoticeBuilder --> RuntimeInfo
  NoticeBuilder --> Notice
  Notice --> Sanitizer
  Sanitizer --> SafeSerializer
  SafeSerializer --> PayloadSerializer
  PayloadSerializer --> SerializedEvent
```

`Notice` is immutable. Parsers are stateless. Raw notice values exist only in process memory. The sanitizer removes sensitive keys and recognized personal data before the safe serializer accepts JSON primitives, bounds nested structures, tolerates invalid encoding, and represents unknown objects without arbitrary application serialization.

Version 0.2 deliberately excludes sampling, retry, and fingerprint policy. These can be inserted after sanitization without changing transport or queue code.

Unit and contract tests verify missing backtraces, cyclic causes, invalid encoding, unsafe objects, payload limits, and the v1 envelope.
