require "chronos"
require "chronos/integrations/capistrano"

Chronos::Integrations::Capistrano.install(self) if respond_to?(:namespace, true) && respond_to?(:after, true)
