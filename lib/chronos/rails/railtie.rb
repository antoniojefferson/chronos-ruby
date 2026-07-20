module Chronos
  module Rails
    # Hooks Chronos installation into the public Rails initializer lifecycle.
    #
    # @responsibility Install integrations after application configuration initializers load.
    # @motivation Ensure generated Chronos configuration exists before hooks are activated.
    # @limits It performs no autoloading and does not use private Rails initialization APIs.
    # @collaborators Rails::Railtie and Chronos::Rails::Installer.
    # @thread_safety Rails invokes the initializer during serialized application boot.
    # @compatibility Rails 4.2 through Rails 5.2; no Zeitwerk requirement.
    # @example
    #   require "chronos/rails"
    # @errors Installer contains optional integration failures and allows Rails to boot.
    # @performance Adds only one initializer and one-time installation work.
    class Railtie < ::Rails::Railtie
      initializer "chronos.install", :after => :load_config_initializers do |application|
        Chronos::Rails::Installer.new.install(application)
      end
    end
  end
end
