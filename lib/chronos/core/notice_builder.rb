require "securerandom"
require "time"

module Chronos
  module Core
    # Normalizes an Exception and caller context into a Notice.
    #
    # @responsibility Coordinate backtrace, causes, runtime, and caller-provided fields.
    # @motivation Isolate Ruby runtime behavior from delivery code.
    # @limits It does not serialize, enqueue, or perform HTTP.
    # @collaborators BacktraceParser, ExceptionCauseCollector, RuntimeInfo, and Notice.
    # @thread_safety Collaborators are stateless and the builder keeps no call state.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   notice = builder.call(RuntimeError.new("failed"), :tags => ["billing"])
    # @performance Linear in backtrace and supplied context size.
    class NoticeBuilder
      def initialize(config, clock = nil)
        @config = config
        @clock = clock || proc { Time.now }
        @backtrace_parser = BacktraceParser.new(config.root_directory)
        @cause_collector = ExceptionCauseCollector.new
        @runtime_info = RuntimeInfo.new
      end

      def call(exception, context = {})
        raise ArgumentError, "exception must be an Exception" unless exception.is_a?(Exception)

        context = {} unless context.is_a?(Hash)
        runtime = @runtime_info.call
        Notice.new(
          :event_id => SecureRandom.uuid,
          :exception_class => safe_class_name(exception),
          :message => safe_message(exception),
          :backtrace => @backtrace_parser.call(exception.backtrace),
          :causes => @cause_collector.call(exception),
          :severity => value(context, :severity) || "error",
          :timestamp => @clock.call.utc.iso8601(6),
          :context => value(context, :context) || context_without_reserved_keys(context),
          :parameters => value(context, :parameters) || {},
          :session => value(context, :session) || {},
          :user => value(context, :user) || {},
          :environment => @config.environment,
          :runtime => runtime[:runtime],
          :versions => {"agent" => Chronos::VERSION, "application" => @config.app_version},
          :host => runtime[:host],
          :process => runtime[:process],
          :thread => runtime[:thread],
          :tags => Array(value(context, :tags)),
          :fingerprint => value(context, :fingerprint)
        )
      end

      private

      RESERVED_KEYS = [:severity, :context, :parameters, :session, :user, :tags, :fingerprint].freeze

      def value(hash, key)
        hash.key?(key) ? hash[key] : hash[key.to_s]
      end

      def context_without_reserved_keys(context)
        context.each_with_object({}) do |(key, child), result|
          result[key] = child unless RESERVED_KEYS.include?(key.to_sym)
        end
      rescue StandardError
        {}
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
