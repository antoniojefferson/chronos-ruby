# Performance

Performance is a functional requirement, but version 0.2 makes no unverified speed claim.

Current controls:

- backtraces are limited to 200 frames;
- hashes and arrays are bounded during serialization;
- strings and total payload size are bounded;
- sanitizer traversal and serializer node count are bounded by the event structure;
- the asynchronous queue has fixed capacity;
- worker count is fixed and threads start lazily;
- producers never wait for queue capacity;
- HTTP open and read timeouts are explicit;
- shutdown and flush have caller-controlled timeouts.

Run the scripts under `benchmarks/` and record Ruby version, operating system, CPU, warmup, iteration count, median, and dispersion before publishing results. `benchmarks/filtering.rb` measures the version 0.2 privacy pass. Request overhead is not measured because automatic request integration is outside version 0.2.

## Version 0.2 development measurement

A local diagnostic run on 2026-07-19 used macOS arm64 (`T8103`), legacy x86_64 Ruby builds, 100 warmup iterations, and 500 measured iterations per script:

| Runtime | Asynchronous local capture | Full serialization | Privacy filtering fixture |
|---|---:|---:|---:|
| Ruby 2.2.10 | 1,857 µs/event | 4,047 µs/event | 798 µs/pass |
| Ruby 2.6.3 | 1,904 µs/event | 4,705 µs/event | 1,037 µs/pass |

The capture benchmark uses an in-memory transport and includes queue draining. The serialization fixture contains 20 backtrace frames; the filtering fixture contains nested fields and 20 repeated items. These are single aggregate development runs, not published performance claims: they do not provide median or dispersion and must be repeated on controlled hardware before comparison with another agent.
