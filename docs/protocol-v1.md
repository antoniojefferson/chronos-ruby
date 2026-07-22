# Protocol v1 stability

The schemas under `contracts/` are the source of truth for protocol v1. Version `0.9.0.pre.3` keeps `schema_version: "1.0"` and treats every required field, enum value, privacy exclusion, and maximum as a compatibility contract.

Compatible changes may add optional bounded fields or new event types accepted by the server. Removing or renaming a field, changing its type/meaning, weakening a bound, or making an optional field required needs a new protocol major schema. Authentication remains outside the JSON payload. Contract tests and `script/verify_docs` must pass before a release.
