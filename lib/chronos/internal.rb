module Chronos
  # Private runtime infrastructure used by the public agent.
  #
  # @responsibility Host bounded concurrency and defensive diagnostics.
  # @motivation Keep lifecycle mechanisms outside the domain.
  # @limits Constants under Internal are not part of the stable public API.
  # @thread_safety Mutable components synchronize their own state.
  # @compatibility Ruby 2.2.10 through Ruby 2.6.
  module Internal; end
end
