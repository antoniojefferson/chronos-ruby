require "socket"

module Chronos
  module Core
    # Collects low-cost runtime identifiers for an event.
    #
    # @responsibility Report Ruby, platform, process, thread, and optional host data.
    # @motivation Provide enough environment context for diagnosis and grouping.
    # @limits It does not enumerate environment variables, gems, or machine secrets.
    # @thread_safety Stateless; all returned hashes are new objects.
    # @compatibility Ruby 2.2.10 through Ruby 2.6 and feature-detected engines.
    # @example
    #   Chronos::Core::RuntimeInfo.new.call
    # @performance Uses constant-time runtime lookups and one hostname lookup.
    class RuntimeInfo
      def call
        {
          :runtime => {
            "ruby_version" => RUBY_VERSION,
            "ruby_engine" => ruby_engine,
            "platform" => RUBY_PLATFORM
          },
          :host => safe_hostname,
          :process => {"pid" => Process.pid},
          :thread => {"id" => Thread.current.object_id.to_s}
        }
      end

      private

      def ruby_engine
        defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"
      end

      def safe_hostname
        Socket.gethostname.to_s
      rescue StandardError
        nil
      end
    end
  end
end
