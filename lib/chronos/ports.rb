module Chronos
  # Stable boundaries implemented by infrastructure adapters.
  #
  # @responsibility Define the behavior expected from external collaborators.
  # @motivation Apply dependency inversion to delivery infrastructure.
  # @limits Interfaces are verified by behavior because Ruby has no interface keyword.
  # @thread_safety Each adapter documents its own guarantees.
  # @compatibility Ruby 2.2.10 through Ruby 2.6.
  module Ports; end
end
