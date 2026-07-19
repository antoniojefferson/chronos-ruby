module Chronos
  # Framework-independent domain values and normalization services.
  #
  # @responsibility Model and normalize Chronos events.
  # @motivation Keep runtime data independent from delivery mechanisms.
  # @limits Does not depend on Rails, Rack, Sidekiq, or Net::HTTP.
  # @thread_safety Components are immutable or stateless unless documented otherwise.
  # @compatibility Ruby 2.2.10 through Ruby 2.6.
  module Core; end
end
