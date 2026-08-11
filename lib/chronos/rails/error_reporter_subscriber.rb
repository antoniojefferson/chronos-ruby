module Chronos
  module Rails
    # Sends exceptions observed by the Rails 7 error reporter to Chronos once.
    # @responsibility Translate the public Rails reporter callback into one notice.
    # @motivation Rails can report handled errors that never reach Rack middleware.
    # @limits Only handled, severity, source, and one bounded component are retained.
    # @collaborators ActiveSupport::ErrorReporter and Chronos facade.
    # @thread_safety Instances contain only an immutable notifier reference.
    # @compatibility Rails 7 public error reporter subscriber API.
    # @example Rails.error.subscribe(ErrorReporterSubscriber.new)
    # @errors Agent and context failures are contained and return false.
    # @performance Allocates one small allowlisted metadata hash per report.
    class ErrorReporterSubscriber
      def initialize(notifier = Chronos)
        @notifier = notifier
      end

      def report(error, handled:, severity:, context:, source: nil)
        details = {
          :context => {"rails_error_reporter" => {
            "handled" => handled == true, "severity" => severity.to_s, "source" => source.to_s
          }}
        }
        details[:context]["rails_error_reporter"]["component"] = component(context)
        @notifier.notify_once(error, details)
      rescue StandardError
        false
      end

      private

      def component(context)
        return "" unless context.is_a?(Hash)

        (context[:controller] || context["controller"] || context[:job] || context["job"]).to_s[0, 128]
      end
    end
  end
end
