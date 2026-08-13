require "chronos"
require "chronos/rails/active_record_query_inspector"
require "chronos/rails/notifications_subscriber"
require "chronos/rails/error_reporter_subscriber"
require "chronos/integrations/active_job"
require "chronos/integrations/sidekiq"
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
  module Rails
    class << self
      # Returns the namespace that owns the Rails application class.
      def application_name(application = ::Rails.application)
        class_name = application.class.name.to_s
        name = class_name.sub(/::Application\z/, "")
        name.empty? || name == class_name ? nil : name
      rescue StandardError
        nil
      end
    end
  end
end
