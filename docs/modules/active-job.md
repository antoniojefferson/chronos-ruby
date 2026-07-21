# Active Job legacy integration

When `ActiveJob::Base` is available, the Rails installer prepends public serialization/execution hooks. Enqueue serialization adds a namespaced `chronos_context` field with schema version plus at most the trace and request identifiers; each identifier is limited to 128 bytes. Public job arguments are unchanged. Deserialization restores this context only around `perform_now`.

The `perform.active_job` subscriber records adapter, job ID, provider job ID, class, queue, execution count, duration, status, and error class. Arguments are omitted. A supplied exception is reported once with bounded job context. The integration never changes retry, acknowledgement, adapter, or original exception behavior.

This metadata can identify a workflow or tenant in some applications. Review retention and identifier generation under the project's privacy policy.
