module Chronos
  module Application
    # Classifies bounded APM observations without inspecting exception messages.
    module ApmErrorClassifier
      private

      def error?(type, payload)
        return status_error?(payload) if type == "request"
        return (payload["status"] || payload[:status]).to_s == "failed" if type == "job"
        return external_http_error?(payload) if type == "external_http"

        !(payload["error_class"] || payload[:error_class]).to_s.empty?
      end

      def external_http_error?(payload)
        return true unless (payload["error_class"] || payload[:error_class]).to_s.empty?
        return true if payload["timeout"] == true || payload[:timeout] == true

        status_error?(payload)
      end

      def status_error?(payload)
        (payload["status"] || payload[:status]).to_i >= 500
      end
    end
  end
end
