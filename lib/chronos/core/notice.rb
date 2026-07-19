module Chronos
  module Core
    # Immutable value object containing a normalized Ruby exception.
    #
    # @responsibility Carry exception and diagnostic context through the pipeline.
    # @motivation Keep transport details separate from exception normalization.
    # @limits It does not sanitize, serialize, enqueue, or send itself.
    # @collaborators NoticeBuilder and PayloadSerializer.
    # @thread_safety Immutable after construction and safe to share.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; independent of Rails.
    # @example
    #   notice.exception_class #=> "RuntimeError"
    # @performance Construction is linear in backtrace and context size.
    class Notice
      ATTRIBUTES = [
        :event_id, :exception_class, :message, :backtrace, :causes,
        :severity, :timestamp, :context, :parameters, :session, :user,
        :environment, :runtime, :versions, :host, :process, :thread,
        :tags, :fingerprint
      ].freeze

      attr_reader(*ATTRIBUTES)

      def initialize(attributes)
        ATTRIBUTES.each do |attribute|
          instance_variable_set("@#{attribute}", deep_freeze(attributes[attribute]))
        end
        freeze
      end

      def to_h
        ATTRIBUTES.each_with_object({}) do |attribute, result|
          result[attribute] = public_send(attribute)
        end
      end

      private

      def deep_freeze(value)
        case value
        when Hash
          value.each do |key, child|
            deep_freeze(key)
            deep_freeze(child)
          end
        when Array
          value.each { |child| deep_freeze(child) }
        end
        value.freeze
      end
    end
  end
end
