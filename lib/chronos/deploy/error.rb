module Chronos
  module Deploy
    # @responsibility Carry static actionable errors and allowlisted diagnostics without raw input.
    # Messages must be static: never interpolate input or exception messages.
    class Error < StandardError
      attr_reader :details

      def initialize(message, details = {})
        super(message)
        @details = details
      end
    end
  end
end
