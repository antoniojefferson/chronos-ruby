# Essential APM aggregation

Version `0.7.0.pre.1` aggregates request, SQL, and job observations locally before delivery. The agent emits versioned `metric_batch` envelopes containing at most 50 metric groups instead of one event per observation. Aggregates drain when `apm_flush_count` observations are reached and whenever `Chronos.flush` or `Chronos.close` runs. No timer or additional APM thread is created.

## Request metrics

Request groups use normalized route and HTTP method. Status codes are counted inside the group so error rate can be calculated without making status part of an unbounded key. Each metric contains count, error count/rate, total, minimum, maximum, average, fixed histogram buckets, and component breakdown. Percentiles remain server-side because retaining every duration locally would violate the memory boundary.

Rack records request metrics for non-Rails applications. Rails controller notifications and Rack share `record_event_once`, so the same request is counted only once. Controller notification data wins when available because its route is more precise.

## SQL metrics and signals

`Chronos::Core::SqlNormalizer` removes block/line comments, quoted literal values, numeric values, booleans, nulls, and repeated `IN` values before producing a SHA-256 fingerprint. Binds are never read. Query dimensions can contain adapter, operation, inferred table, bounded normalized query, fingerprint, Active Record operation name, cache flag, connection role/shard, and a bounded source frame for slow sampled queries.

Local signals are intentionally heuristic:

- `slow_query` when duration reaches `apm_slow_query_threshold_ms`;
- `repeated_query` after the same fingerprint appears again in one trace;
- `possible_n_plus_one` once when the configured repetition threshold is reached;
- `long_transaction` for transaction-labelled SQL over its threshold;
- `connection_error` and `deadlock` from bounded exception class names.

The SaaS must confirm and correlate these signals. They are not proof of an N+1, deadlock, or application defect.

## Bounded state

- at most `apm_max_groups` metric groups;
- at most `apm_max_groups` active trace trackers;
- at most `apm_max_queries_per_request` fingerprints per trace;
- at most 19 configured histogram boundaries plus `+Inf`;
- at most `apm_batch_size` groups per payload, with a hard maximum of 50;
- trackers are removed when their request completes and all remaining trackers are cleared on aggregate drain.

New groups beyond capacity are dropped and counted in `dropped_groups`. Existing groups continue accumulating. The state is process-local and is lost on restart.

## Breakdown

The contract supports `database`, `view`, `external_http`, `cache`, `queue`, `application`, and `unknown`. Version 0.7 fills database/view/cache within a traced request, queue/application for jobs, and residual application time for requests. External HTTP instrumentation begins in version 0.8.

## Configuration

```ruby
Chronos.configure do |config|
  # connection settings omitted
  config.apm_enabled = true
  config.apm_max_groups = 200
  config.apm_flush_count = 100
  config.apm_batch_size = 50
  config.apm_max_queries_per_request = 100
  config.apm_slow_query_threshold_ms = 500.0
  config.apm_long_transaction_threshold_ms = 1000.0
  config.apm_n_plus_one_threshold = 5
  config.apm_histogram_buckets = [5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0]
end
```

Setting `apm_enabled = false` restores individual request/query/job telemetry for compatibility diagnostics. Cache events remain individual in 0.7 while also contributing to an existing request breakdown.
