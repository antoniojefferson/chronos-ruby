require "chronos"

sidekiq_available = begin
  require "sidekiq"
  true
rescue LoadError
  false
end

require "chronos/integrations/sidekiq"

Chronos::Integrations::Sidekiq.install if sidekiq_available && defined?(::Sidekiq)
