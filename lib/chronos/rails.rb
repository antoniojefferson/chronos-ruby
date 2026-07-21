require "chronos"
require "chronos/rails/notifications_subscriber"
require "chronos/integrations/active_job"
require "chronos/rails/installer"

require "chronos/rails/railtie" if defined?(::Rails::Railtie)

module Chronos
  # Legacy Rails integration loaded explicitly after Rails is available.
  #
  # @responsibility Namespace Railtie, installer, and notification subscribers.
  # @motivation Keep Rails and ActiveSupport out of the framework-independent core.
  # @limits Version 0.5 targets public APIs present in Rails 4.2 and 5.2.
  # @thread_safety Installation and subscriptions are protected against duplication.
  # @compatibility Rails 4.2 through Rails 5.2 with their supported legacy Rubies.
  module Rails; end
end
