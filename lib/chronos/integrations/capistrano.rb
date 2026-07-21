module Chronos
  module Integrations
    # Optional Capistrano task installer using only the public task DSL.
    #
    # @responsibility Register one post-publish task that delegates explicit values to notify_deploy.
    # @motivation Legacy deployments need release reporting without a Capistrano runtime dependency.
    # @limits Values are read only from configured Capistrano variables; Git and ENV are not inspected.
    # @collaborators Capistrano/Rake DSL and the Chronos public facade.
    # @thread_safety Installation is idempotent per DSL object before task execution.
    # @compatibility Capistrano task DSLs available to supported Ruby 2.2.10 through Ruby 2.6 apps.
    # @example
    #   require "chronos/capistrano"
    # @errors Missing DSL methods return false; notification failures are contained by Chronos.
    # @performance Adds one task and one after hook; no background worker is created.
    module Capistrano
      INSTALLED_KEY = :@__chronos_capistrano_installed

      class << self
        def install(dsl)
          return false if dsl.instance_variable_get(INSTALLED_KEY)
          return false unless compatible?(dsl)

          dsl.send(:namespace, :chronos) do
            dsl.send(:desc, "Notify Chronos about the published deployment") if dsl.respond_to?(:desc, true)
            dsl.send(:task, :notify_deploy) { notify(dsl) }
          end
          dsl.send(:after, "deploy:published", "chronos:notify_deploy")
          dsl.instance_variable_set(INSTALLED_KEY, true)
          true
        rescue StandardError
          false
        end

        def notify(dsl)
          Chronos.notify_deploy(
            :environment => value(dsl, :stage).to_s,
            :revision => value(dsl, :current_revision) || value(dsl, :branch),
            :version => value(dsl, :chronos_version) || value(dsl, :release_name),
            :repository => value(dsl, :repo_url), :actor => value(dsl, :chronos_actor),
            :deploy_id => value(dsl, :chronos_deploy_id), :service => value(dsl, :chronos_service),
            :region => value(dsl, :chronos_region), :instance => value(dsl, :chronos_instance)
          )
        rescue StandardError
          false
        end

        private

        def compatible?(dsl)
          [:namespace, :task, :after, :fetch].all? { |name| dsl.respond_to?(name, true) }
        end

        def value(dsl, name)
          dsl.send(:fetch, name, nil)
        rescue StandardError
          nil
        end
      end
    end
  end
end
