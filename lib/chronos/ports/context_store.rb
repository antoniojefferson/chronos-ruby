module Chronos
  module Ports
    # Conceptual storage port for execution-scoped context.
    #
    # @responsibility Define get, set, clear, and scoped context behavior.
    # @motivation Let integrations isolate request state without depending on a thread implementation.
    # @limits The port does not prescribe thread, fiber, or distributed propagation semantics.
    # @collaborators Agent and context-store adapters.
    # @thread_safety Implementations must isolate concurrent executions.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   Chronos::Ports::ContextStore.compatible?(store) #=> true
    # @errors Compatibility checks never invoke application methods.
    module ContextStore
      REQUIRED_METHODS = [:get, :set, :clear, :with_context].freeze

      def self.compatible?(object)
        REQUIRED_METHODS.all? { |method_name| object.respond_to?(method_name) }
      end
    end
  end
end
