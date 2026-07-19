module Chronos
  # Base error raised by explicit Chronos setup operations.
  #
  # @responsibility Provide a common ancestor for errors callers may handle.
  # @motivation Separate agent setup failures from application failures.
  # @limits Runtime capture and delivery errors never escape through this class.
  # @thread_safety Error instances are not shared by the agent.
  # @compatibility Ruby 2.2.10 and newer legacy runtimes.
  # @example
  #   rescue Chronos::Error => error
  #     warn error.message
  class Error < StandardError; end

  # Raised when a configuration cannot produce a valid immutable snapshot.
  #
  # @responsibility Report all invalid configuration fields before agent startup.
  # @motivation Fail early during explicit setup instead of failing in requests.
  # @limits It is not used for transport or event errors.
  # @thread_safety Instances are immutable after construction by convention.
  # @compatibility Ruby 2.2.10 and newer legacy runtimes.
  # @example
  #   Chronos.configure { |config| config.project_key = nil }
  class ConfigurationError < Error; end
end
