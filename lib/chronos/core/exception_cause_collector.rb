module Chronos
  module Core
    # Collects a bounded exception cause chain with cycle protection.
    #
    # @responsibility Normalize nested Exception#cause values.
    # @motivation Preserve root-cause information without unbounded traversal.
    # @limits It records class and message only; each cause backtrace is handled elsewhere.
    # @collaborators NoticeBuilder.
    # @thread_safety Uses only call-local state.
    # @compatibility Feature-detects Exception#cause for legacy runtimes.
    # @example
    #   collector.call(exception)
    # @performance Constant memory bounded by max_depth.
    class ExceptionCauseCollector
      DEFAULT_MAX_DEPTH = 10

      def initialize(max_depth = DEFAULT_MAX_DEPTH)
        @max_depth = max_depth
      end

      def call(exception)
        causes = []
        seen = {}
        current = exception

        @max_depth.times do
          break unless current.respond_to?(:cause)
          current = safe_cause(current)
          break unless current
          break if seen[current.object_id]

          seen[current.object_id] = true
          causes << {
            "class" => safe_class_name(current),
            "message" => safe_message(current)
          }
        end

        causes
      end

      private

      def safe_cause(exception)
        exception.cause
      rescue StandardError
        nil
      end

      def safe_class_name(exception)
        exception.class.name.to_s
      rescue StandardError
        "Exception"
      end

      def safe_message(exception)
        exception.message.to_s
      rescue StandardError
        "<unreadable exception message>"
      end
    end
  end
end
