module Chronos
  module Ports
    # Documents the optional read-only database-inspection boundary used by SQL monitoring.
    #
    # @responsibility Define compatibility for index, statistics, and plan inspection adapters.
    # @motivation Keep database and ActiveRecord behavior outside the framework-independent core.
    # @limits It does not require inspection, execute DDL, or prescribe a database driver.
    # @thread_safety Implementations define their own connection and concurrency guarantees.
    # @compatibility The compatibility check uses APIs available in Ruby 2.2.10.
    # @example
    #   QueryInspector.compatible?(adapter) #=> true
    # @errors Compatibility checks contain objects with failing reflection methods.
    module QueryInspector
      REQUIRED_METHODS = [:call].freeze

      def self.compatible?(object)
        REQUIRED_METHODS.all? { |method_name| object.respond_to?(method_name) }
      rescue StandardError
        false
      end
    end
  end
end
