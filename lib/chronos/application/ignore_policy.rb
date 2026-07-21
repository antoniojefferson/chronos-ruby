module Chronos
  module Application
    # Stores and evaluates bounded application-owned exception ignore rules.
    #
    # @responsibility Decide whether a normalized Notice should be discarded locally.
    # @motivation Expected application failures should not consume queue or network capacity.
    # @limits Rules inspect only the bounded Notice API and cannot be installed remotely.
    # @collaborators CaptureException and application-provided callables.
    # @thread_safety Rule registration and snapshots are protected by a mutex.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   policy.add { |notice| notice.exception_class == "ExpectedError" }
    # @errors A failing rule is contained, logged, and treated as not matching.
    # @performance The number of evaluated rules is capped by configuration.
    class IgnorePolicy
      def initialize(rules, limit, logger)
        @rules = Array(rules).dup
        @limit = limit
        @logger = logger
        @mutex = Mutex.new
      end

      def add(rule = nil, &block)
        candidate = rule || block
        return false unless candidate.respond_to?(:call)

        @mutex.synchronize do
          return false if @rules.length >= @limit

          @rules << candidate
        end
        true
      rescue StandardError
        false
      end

      def ignored?(notice)
        rules = @mutex.synchronize { @rules.dup }
        rules.any? { |rule| safely_matches?(rule, notice) }
      rescue StandardError
        false
      end

      private

      def safely_matches?(rule, notice)
        rule.call(notice) == true
      rescue StandardError => error
        @logger.warn("Chronos ignore rule failed: #{error.class}")
        false
      end
    end
  end
end
