# Semantic Versioning policy

Chronos follows Semantic Versioning for the gem API and the independently versioned event protocol.

- Before `1.0.0`, incompatible changes may occur only in a documented prerelease and must appear in the changelog and migration notes.
- From `1.0.0`, patch releases contain compatible fixes, minor releases add compatible capability, and major releases may remove or change public behavior.
- Public API includes documented `Chronos` methods, configuration options, supported require paths, integration entry points, and documented return/error behavior.
- Internal constants and files explicitly described as internal are not public API.
- The JSON `schema_version` is independent of the gem version. Additive optional v1 fields are compatible; removing, renaming, or changing required v1 fields requires a new protocol major version.

A release is not promoted to stable while its supported matrix or mandatory release gates are incomplete.
