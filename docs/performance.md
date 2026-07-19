# Performance

Performance is a functional requirement, but version 0.1 makes no unverified speed claim.

Current controls:

- backtraces are limited to 200 frames;
- hashes and arrays are bounded during serialization;
- strings and total payload size are bounded;
- the asynchronous queue has fixed capacity;
- worker count is fixed and threads start lazily;
- producers never wait for queue capacity;
- HTTP open and read timeouts are explicit;
- shutdown and flush have caller-controlled timeouts.

Run the scripts under `benchmarks/` and record Ruby version, operating system, CPU, warmup, iteration count, median, and dispersion before publishing results. Request overhead is not measured because automatic request integration is outside version 0.1.
