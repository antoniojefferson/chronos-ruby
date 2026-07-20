# Performance

Performance is a functional requirement, but version 0.3 makes no unverified speed claim.

Current controls:

- backtraces are limited to 200 frames;
- hashes and arrays are bounded during serialization;
- strings and total payload size are bounded;
- sanitizer traversal and serializer node count are bounded by the event structure;
- the asynchronous queue has fixed capacity;
- worker count is fixed and threads start lazily;
- producers never wait for queue capacity;
- HTTP open and read timeouts are explicit;
- retry count, delay, jitter, and `Retry-After` are capped;
- the circuit breaker suppresses requests during sustained failure;
- retry backlog capacity is fixed and may be disabled;
- shutdown and flush have caller-controlled timeouts.

Run the scripts under `benchmarks/` and record Ruby version, operating system, CPU, warmup, iteration count, median, and dispersion before publishing results. `benchmarks/filtering.rb` measures privacy filtering, while `benchmarks/retry_backlog.rb` measures fixed-memory behavior with an unavailable in-memory transport. Request overhead is not measured because automatic request integration is outside version 0.3.

## Version 0.2 development measurement

A local diagnostic run on 2026-07-19 used macOS arm64 (`T8103`), legacy x86_64 Ruby builds, 100 warmup iterations, and 500 measured iterations per script:

| Runtime | Asynchronous local capture | Full serialization | Privacy filtering fixture |
|---|---:|---:|---:|
| Ruby 2.2.10 | 1,857 µs/event | 4,047 µs/event | 798 µs/pass |
| Ruby 2.6.3 | 1,904 µs/event | 4,705 µs/event | 1,037 µs/pass |

The capture benchmark uses an in-memory transport and includes queue draining. The serialization fixture contains 20 backtrace frames; the filtering fixture contains nested fields and 20 repeated items. These are single aggregate development runs, not published performance claims: they do not provide median or dispersion and must be repeated on controlled hardware before comparison with another agent.

## Version 0.3 resilience benchmark

Run:

```bash
ITERATIONS=10000 bundle _1.17.3_ exec ruby benchmarks/retry_backlog.rb
```

The benchmark opens the circuit after one synthetic network failure, retains at most 100 serialized events, and measures bounded rejection into a full backlog. It performs no network I/O and is intended to detect accidental unbounded growth or excessive control-path overhead, not to claim production throughput.

A local diagnostic run on 2026-07-20 used Ruby 2.2.10 on macOS arm64 with 1,000 capture, serialization, and filtering iterations plus 10,000 queue and outage iterations:

| Measurement | Result |
|---|---:|
| Asynchronous local capture | 1,824 µs/event |
| Full serialization | 3,961 µs/event |
| Privacy filtering fixture | 777 µs/pass |
| Bounded queue | 1,648,533 operations/second |
| Open-circuit backlog handling | 88,922 operations/second |

The outage run retained exactly 100 events and rejected 9,900 additional events without growing the backlog. These are single development runs without median or dispersion and are not comparative performance claims.
