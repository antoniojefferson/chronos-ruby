module Chronos
  module Rails
    # Installs Rails middleware and subscribers exactly once per application.
    #
    # @responsibility Apply feature-detected integration hooks after Rails initializers load.
    # @motivation Centralize version-neutral installation outside Railtie DSL code.
    # @limits It does not configure credentials or depend on private Rails APIs.
    # @collaborators Rails application middleware, NotificationsSubscriber, and Chronos facade.
    # @thread_safety A mutex protects the per-application installation registry.
    # @compatibility Rails 4.2 through Rails 5.2 without Zeitwerk.
    # @example
    #   Chronos::Rails::Installer.new.install(Rails.application)
    # @errors Missing optional Rails capabilities return false without affecting boot.
    # @performance Installation is one-time; request work is delegated to bounded integrations.
    class Installer
      @mutex = Mutex.new
      @applications = {}

      class << self
        attr_reader :mutex, :applications
      end

      def initialize(notifier = Chronos, subscriber = nil)
        @notifier = notifier
        @subscriber = subscriber || NotificationsSubscriber.new(notifier)
      end

      def install(application)
        options = @notifier.rails_integration_options(environment, console?)
        return false unless options[:enabled]

        self.class.mutex.synchronize do
          return false if self.class.applications[application.object_id]

          install_middleware(application, options)
          install_active_job
          @subscriber.install
          self.class.applications[application.object_id] = true
        end
        true
      rescue StandardError
        false
      end

      def rails_version
        defined?(::Rails) && ::Rails.respond_to?(:version) ? ::Rails.version.to_s : "unknown"
      end

      private

      def install_middleware(application, options)
        middleware = application.config.middleware
        return false unless middleware.respond_to?(:use)

        middleware.use(
          Chronos::Integrations::Rack::Middleware,
          :include_user_agent => options[:include_user_agent]
        )
        true
      end

      def install_active_job
        return false unless defined?(::ActiveJob::Base)

        Chronos::Integrations::ActiveJob.install(::ActiveJob::Base, @notifier)
      end

      def environment
        defined?(::Rails) && ::Rails.respond_to?(:env) ? ::Rails.env.to_s : nil
      end

      def console?
        defined?(::Rails::Console)
      end
    end
  end
end
