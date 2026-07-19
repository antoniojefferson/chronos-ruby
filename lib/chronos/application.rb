module Chronos
  # Application use cases that coordinate the core and ports.
  #
  # @responsibility Orchestrate capture and delivery workflows.
  # @motivation Keep policy separate from domain values and adapters.
  # @limits Does not implement HTTP or framework hooks.
  # @thread_safety Use cases rely on thread-safe collaborators.
  # @compatibility Ruby 2.2.10 through Ruby 2.6.
  module Application; end
end
