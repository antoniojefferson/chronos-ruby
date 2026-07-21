# Configuration module

Configuration separates mutable setup from immutable runtime state. `Chronos::Configuration` owns defaults and validation; `Snapshot` is shared with runtime components.

This module is separate from capture because configuration errors should be found before any event enters the pipeline. It can be extended by adding a validated attribute and immutable snapshot field.

Risks include accidentally logging credentials and changing settings while events run. The snapshot prevents mutation, while logger and transport code never interpolate `project_key`.

Tests in `spec/unit/configuration_spec.rb` verify required fields, HTTPS defaults, immutable containers, disabled operation, and bounded numeric settings.

Version 0.7 adds bounded APM capacities, thresholds, and histogram boundaries. Invalid zero/negative capacities, batches above 50, N+1 thresholds below two, and non-increasing histogram boundaries are rejected before agent construction. See [Essential APM aggregation](apm-aggregation.md).

Version 0.8 adds Boolean HTTP/dependency switches, `:none`/`:sha256` cache-key policy, and a dependency limit from 1 to 200. Invalid values are rejected before instrumentation or collection starts. See [External HTTP](external-http.md), [Cache observability](cache-observability.md), and [Dependency inventory](dependencies.md).

Version 0.9 adds optional `revision`, `deploy_id`, `region`, and `instance_id` strings, each limited to 128 bytes. Together with the existing release/environment/service options they form immutable event correlation. See [Deploy tracking and release correlation](deploy-tracking.md).
