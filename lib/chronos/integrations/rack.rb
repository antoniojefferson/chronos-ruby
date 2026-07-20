module Chronos
  module Integrations
    # Rack protocol integrations that do not require Rack at gem load time.
    #
    # @responsibility Namespace Rack-compatible middleware.
    # @motivation Permit optional use without adding a runtime Rack dependency.
    # @limits It does not provide Rails-specific route discovery.
    # @thread_safety Middleware instances may be shared by concurrent Rack threads.
    # @compatibility Rack 1.x and 2.x protocol shapes on Ruby 2.2.10 through Ruby 2.6.
    module Rack; end
  end
end
