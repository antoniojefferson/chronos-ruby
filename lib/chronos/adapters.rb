module Chronos
  # Infrastructure implementations of Chronos ports.
  #
  # @responsibility Connect the agent to HTTP and future external systems.
  # @motivation Isolate standard-library and vendor-specific behavior.
  # @limits Adapters must not add policy to the domain pipeline.
  # @thread_safety Defined by each adapter.
  # @compatibility Ruby 2.2.10 through Ruby 2.6.
  module Adapters; end
end
