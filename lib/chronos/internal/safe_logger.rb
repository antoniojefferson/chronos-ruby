module Chronos
  module Internal
    # Protects the host application from logger failures and recursive diagnostics.
    #
    # @responsibility Emit bounded internal messages through a configured logger.
    # @motivation Diagnostics must never become a new application failure.
    # @limits It does not store logs or include credentials and payloads.
    # @thread_safety Uses a mutex for recursion protection across threads.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   logger.warn("transport failed")
    class SafeLogger
      MAX_MESSAGE_BYTES = 1024

      def initialize(logger)
        @logger = logger
        @mutex = Mutex.new
        @logging = false
      end

      def debug(message)
        write(:debug, message)
      end

      def warn(message)
        write(:warn, message)
      end

      private

      def write(level, message)
        return unless @logger && @logger.respond_to?(level)

        allowed = @mutex.synchronize do
          next false if @logging
          @logging = true
        end
        return unless allowed

        @logger.public_send(level, bounded(message))
      rescue StandardError
        nil
      ensure
        @mutex.synchronize { @logging = false } if allowed
      end

      def bounded(message)
        text = message.to_s
        text.bytesize > MAX_MESSAGE_BYTES ? text.byteslice(0, MAX_MESSAGE_BYTES) : text
      rescue StandardError
        "Chronos internal diagnostic unavailable"
      end
    end
  end
end
