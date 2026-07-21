# Deploy tracking and release correlation

Version `0.9.0.pre.1` adds synchronous deploy notifications and a bounded correlation block to every exception and telemetry envelope. The SaaS can compare errors and performance before and after a release using release, revision, deploy ID, environment, service, region, and instance.

## Public API

Configure the agent, then provide deploy metadata explicitly:

```ruby
Chronos.notify_deploy(
  :environment => "production",
  :revision => ENV["GIT_SHA"],
  :version => ENV["APP_VERSION"],
  :repository => "owner/repository",
  :actor => ENV["DEPLOY_USER"],
  :deploy_id => ENV["DEPLOY_ID"],
  :service => "billing",
  :region => "sa-east-1",
  :instance => "web-1"
)
```

Environment is required, and either revision or version must be present. A UUID deploy ID is generated when none is supplied. The call uses synchronous delivery, bypasses ordinary event sampling, then refreshes the bounded dependency inventory for the new release and flushes it before returning. Local/remote event disabling and the kill switch still apply. It returns `false` instead of leaking configuration, normalization, serialization, or transport failures.

Fields are limited to 128 bytes, except repository at 512 bytes. HTTP and SCP-style repository credentials are stripped before serialization. The shared sanitizer still filters explicit actor/repository content. Do not send access tokens, e-mail addresses, or unnecessary personal data.

## Correlation on application events

Set the values that identify the currently running release during normal application configuration:

```ruby
Chronos.configure do |config|
  # project and endpoint settings omitted
  config.app_version = ENV["APP_VERSION"]
  config.revision = ENV["GIT_SHA"]
  config.deploy_id = ENV["DEPLOY_ID"]
  config.environment = ENV["APP_ENV"] || "production"
  config.service_name = "billing"
  config.region = ENV["REGION"]
  config.instance_id = ENV["INSTANCE_ID"]
end
```

The gem never reads these variables itself. The host application chooses each source. Configuration snapshots are immutable, so `notify_deploy` does not mutate correlation for an already running process; newly deployed processes must start with their own release values.

## Capistrano

Require the optional entry point after Capistrano loads:

```ruby
require "chronos/capistrano"

set :chronos_version, ENV["APP_VERSION"]
set :chronos_actor, ENV["DEPLOY_USER"]
set :chronos_deploy_id, ENV["DEPLOY_ID"]
set :chronos_service, "billing"
set :chronos_region, ENV["DEPLOY_REGION"]
```

It registers `chronos:notify_deploy` after `deploy:published`, once per DSL object. Revision, stage, and repository use the public Capistrano variables `current_revision`, `stage`, and `repo_url`; all Chronos-specific values are optional and explicit. The integration adds no Capistrano runtime dependency.

## Manual, Kamal, and GitHub Actions

[`examples/deploy/notify.rb`](../../examples/deploy/notify.rb) is the shared command. It requires project credentials/host and deploy environment, reads only named variables, notifies synchronously, closes the agent, and exits nonzero on failure.

For Kamal, pass the variables to the deployed container or command environment and execute after publication:

```bash
kamal app exec --reuse "bundle exec ruby examples/deploy/notify.rb"
```

Adapt the command to the application's Kamal hook lifecycle and secret-management policy. The repository also provides a non-active [GitHub Actions workflow example](../../examples/deploy/github-actions.yml) using read-only repository permission and secret-scoped Chronos credentials.

For a network-free payload demonstration:

```bash
bundle _1.17.3_ exec ruby examples/plain-ruby/deploy_tracking.rb
```

## Limitations

- delivery is process-local and uses the existing finite retry/circuit/backlog policy;
- an unsuccessful synchronous delivery returns `false`; deployment policy decides whether that blocks publication;
- Capistrano auto-registration requires its task DSL to be loaded first;
- Kamal integration is command/documentation based, not a Kamal plugin;
- repository and actor are explicit metadata and remain subject to application privacy review.
