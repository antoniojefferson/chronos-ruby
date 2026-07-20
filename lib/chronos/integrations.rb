module Chronos
  # Optional framework entry points kept outside the framework-independent core.
  #
  # @responsibility Namespace integration adapters such as Rack middleware.
  # @motivation Keep framework loading optional for plain Ruby applications.
  # @limits Integrations may depend only on documented public agent behavior.
  # @thread_safety Each integration documents its own guarantees.
  # @compatibility Version 0.4 supports Rack protocol behavior on Ruby 2.2.10 through 2.6.
  module Integrations; end
end
