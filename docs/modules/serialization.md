# Safe serialization module

`Chronos::Core::SafeSerializer` converts sanitized values into JSON primitives without invoking `to_json` or `to_s` on arbitrary application objects. Unknown objects become a class-name placeholder.

The serializer limits depth, visited nodes, hash keys, array items, key bytes, and string bytes. It detects circular hashes and arrays, repairs invalid UTF-8, and contains unreadable values. These structural budgets bound processing time and memory without using asynchronous interruption such as `Timeout` inside application code.

`PayloadSerializer` owns the versioned event envelope and composes `Sanitizer` before `SafeSerializer`. If the resulting JSON exceeds `max_payload_size`, caller-controlled fields are compacted. An event that still cannot fit is rejected before queueing.

The serializer is stateless across calls and safe for concurrent capture. Tests in `spec/unit/core/safe_serializer_spec.rb` and `spec/unit/core/payload_serializer_spec.rb` cover unsafe objects, cycles, invalid encoding, structural limits, and total payload limits.
