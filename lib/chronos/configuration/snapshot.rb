module Chronos
  # Immutable configuration shared by all runtime components.
  #
  # @responsibility Expose validated settings without mutable containers.
  # @motivation Keep capture behavior stable while multiple threads run.
  # @limits It cannot be edited after creation.
  # @collaborators Configuration and runtime services.
  # @thread_safety Safe to share between threads after construction.
  # @compatibility Ruby 2.2.10 through Ruby 2.6.
  # @example
  #   snapshot.enabled_for_environment? #=> true
  # @errors Construction occurs only after Configuration validation.
  # @performance Deep freezing is paid once during configuration.
  Configuration::Snapshot = Class.new do
    attr_reader(*Configuration::ATTRIBUTES)

    def initialize(values)
      Configuration::ATTRIBUTES.each do |attribute|
        value = values[attribute]
        deep_freeze(value)
        instance_variable_set("@#{attribute}", value)
      end
      freeze
    end

    def enabled_for_environment?
      enabled && !ignored_environments.map(&:to_s).include?(environment.to_s)
    end

    private # rubocop:disable Layout/AccessModifierIndentation

    def deep_freeze(value)
      return value if value.respond_to?(:call) || context_store?(value)

      case value
      when Hash
        value.each do |key, child|
          deep_freeze(key)
          deep_freeze(child)
        end
      when Array
        value.each { |child| deep_freeze(child) }
      end
      value.freeze
    end

    def context_store?(value)
      Configuration::CONTEXT_STORE_METHODS.all? { |method_name| value.respond_to?(method_name) }
    rescue StandardError
      false
    end
  end
end
