# Transitional deploy CLI

Version 1.2.2 ports the CLI/security contract from legacy 1.1.4 while preserving Ruby >= 2.7 and < 3.5 and the existing transitional integrations. After the release is published and installed:

```sh
export CHRONOS_PROJECT_ID=your-project
# Inject CHRONOS_PROJECT_KEY through the deployment secret mechanism.
export CHRONOS_ENVIRONMENT=production
export CHRONOS_DEPLOY_ID=stable-publication-identity
export CHRONOS_DEPLOY_REVISION=revision-of-the-actually-published-artifact
bundle exec chronos deploy notify
```

No Ruby notification script needs to be copied. The CLI does not boot Rails or read credentials/initializers implicitly. CHRONOS_SERVICE_NAME must match runtime service configuration; CHRONOS_DEPLOY_VERSION can replace the revision. The default host is https://chronosmonitor.com.br; CHRONOS_HOST overrides it with HTTPS only, without URL credentials, query or fragment.

Canonical variables: CHRONOS_PROJECT_ID, CHRONOS_PROJECT_KEY, CHRONOS_HOST, CHRONOS_ENVIRONMENT, CHRONOS_SERVICE_NAME, CHRONOS_DEPLOY_ID, CHRONOS_DEPLOY_REVISION, CHRONOS_DEPLOY_VERSION. Aliases: DEPLOY_ENVIRONMENT, SERVICE_NAME, DEPLOY_ID, GIT_SHA, APP_VERSION. Conflicting aliases are errors. Explicit public options override ENV, which overrides optional config/chronos-deploy.yml. The key is ENV-only. YAML accepts only string values for project_id, host, environment, service_name, deploy_id, revision and version; never persist secrets there.

`deploy diagnose --offline` validates complete notify configuration locally without authenticating credentials. `deploy verify` uses the existing correlated receipt and sends no deploy or dependency inventory. A receipt is not proof of SaaS projection. Help/version are local. `--timeout` accepts 0 < seconds <= 60 and bounds transport/flush operations, not one global process deadline. Retries/backlog are disabled for this short-lived CLI. Notify can still produce dependency events.

Operational JSON uses schema_version=1, success and state; verify also exposes verification_status. Exit codes: 0 local/confirmed success, 1 invalid configuration, 2 unconfirmed delivery, 3 internal failure. `--on-error=warn` converts only unconfirmed delivery to process status 0 and retains success=false. Do not retry blindly: the receiver may already have accepted an event. A stable deployment ID does not guarantee exactly-once event consumption or billing.

Generate integrations explicitly:

```sh
bundle exec chronos deploy install --provider kamal --dry-run
bundle exec chronos deploy install --provider kamal
bundle exec chronos deploy install --provider kamal --check
bundle exec rails generate chronos:deploy:install --provider=kamal
```

Providers: kamal, capistrano, github-actions, gitlab-ci, jenkins and azure-devops. Use --root for an explicit destination. Equal content is unchanged; conflicts preserve customer files and expose only the proposed template. Merge manually before considering --force. POSIX installation (Linux/macOS) uses descriptor-relative operations, bounded reads and no-follow opens to prevent symlink redirection. No pipeline is activated automatically and no Gemfile/lockfile/dependency is modified by the installer.

Kamal creates .kamal/hooks/post-deploy; Capistrano creates lib/capistrano/tasks/chronos_deploy.rake and runs locally after deploy:published. Do not also load chronos/capistrano. CI fragments are generated in config/chronos/deploy for manual merge after the real successful publication; explicitly export its actual identity/revision outputs. The GitLab fragment is hidden and must be incorporated into an existing job. A modern deployment runner does not automatically belong to this gem's Ruby matrix.

Use [transitional Docker tests](../README.md#tests) and [1.2.2 readiness](release-1.2.2-readiness.md). The historical legacy ADR describes the origin; current publication and capability decisions belong to this release's readiness document. SaaS recipe selection must use explicit per-line capabilities and retain fallback for older clients. Rails boot/credentials integration and the Ruby 4/Rails 8 line remain separate work.
