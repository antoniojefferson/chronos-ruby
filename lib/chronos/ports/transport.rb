module Chronos
  module Ports
    # Result returned by transport adapters instead of raising into the application.
    #
    # @responsibility Describe delivery outcome and retry classification.
    # @motivation Keep HTTP implementation details outside the application layer.
    # @limits It does not schedule retries; retry is outside version 0.2.
    # @thread_safety Immutable after construction.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    class TransportResult
      attr_reader :status, :status_code, :retry_after, :error

      def initialize(status, options = {})
        @status = status
        @status_code = options[:status_code]
        @retry_after = options[:retry_after]
        @error = options[:error]
        freeze
      end

      def success?
        status == :success
      end

      def retryable?
        [:rate_limited, :server_error, :network_error].include?(status)
      end
    end

    # Conceptual transport port implemented by delivery adapters.
    #
    # @responsibility Define send_event, send_batch, healthy?, and close behavior.
    # @motivation Let capture code depend on a stable boundary instead of Net::HTTP.
    # @limits Ruby does not enforce this interface; adapters are verified by contract tests.
    # @thread_safety Implementations must document their own synchronization.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    module Transport
      REQUIRED_METHODS = [:send_event, :send_batch, :healthy?, :close].freeze

      def self.compatible?(object)
        REQUIRED_METHODS.all? { |method_name| object.respond_to?(method_name) }
      end
    end
  end
end
