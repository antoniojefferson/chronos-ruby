require File.expand_path("../boot", __FILE__)
require "rails/all"
require "chronos/rails"

Bundler.require(*Rails.groups)

module ChronosLegacyExample
  # Minimal Rails application used only by the legacy compatibility smoke gate.
  class Application < Rails::Application
    config.eager_load = false
    config.cache_store = :memory_store
    config.active_job.queue_adapter = :inline if config.respond_to?(:active_job)
    config.action_mailer.delivery_method = :test
    config.secret_key_base = "development-only-chronos-example"
  end
end
