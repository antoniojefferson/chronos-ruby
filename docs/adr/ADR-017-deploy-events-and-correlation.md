# ADR-017 — Synchronous deploy events and immutable release correlation

## Status

Accepted for version 0.9.

## Context

The SaaS needs stable release dimensions to compare error and performance behavior before and after deployments. Deployment tools are short-lived processes, while application telemetry is long-lived and concurrent. Implicit Git, lockfile, or environment discovery would make behavior surprising and could expose credentials.

## Decision

Add a versioned `deploy` telemetry payload delivered synchronously through the existing transport policy. Require an environment and either revision or version, generate a deploy ID when omitted, bound every field, and remove credentials from common repository URL forms.

Emit a `correlation` object on every new v1 envelope with release, revision, deploy ID, environment, service, region, and instance. Keep the schema property optional so payloads from earlier 0.x clients remain valid. Populate it from the immutable configuration snapshot for application events and from normalized deploy fields for deploy events. Do not mutate a running agent's correlation after notification.

Refresh the bounded dependency inventory after a successful deploy notification. Integrate Capistrano through its task DSL without a runtime dependency. Support Kamal by documented command and GitHub Actions through an example workflow.

## Alternatives

Reading Git state, all environment variables, or deployment manifests automatically was rejected for determinism and privacy. Asynchronous-only deploy delivery was rejected because short-lived commands can exit before queue drain. Mutating global release state after `notify_deploy` was rejected because concurrent events could receive mixed correlation. Adding direct dependencies on Capistrano, Kamal, or GitHub SDKs was rejected for the legacy compatibility line.

## Consequences

Every event has a stable bounded correlation shape and deploy commands receive an explicit success result. Applications must pass release metadata into each newly started process. Integration setup remains explicit, and delivery failure policy stays under the deployment pipeline's control.
