require "json"

module Chronos
  module Core
    # Immutable result returned by an explicit Chronos integration verification.
    #
    # @responsibility Expose a bounded, JSON-safe verification outcome to Ruby and Rake callers.
    # @motivation Report credential, receiver, and acknowledgement state without exposing raw responses.
    # @limits It never includes project keys, response bodies, stack traces, or receiver internals.
    # @collaborators VerifyIntegration and Chronos::RakeTasks.
    # @thread_safety The object and all nested values are immutable after construction.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; independent of Rails.
    # @example
    #   result = Chronos.verify_integration
    #   puts result.to_json
    # @errors Invalid input is normalized to safe empty values.
    # @performance Construction visits only the small allowlisted verification response.
    class IntegrationVerificationResult
      SCHEMA_VERSION = "1.0".freeze

      attr_reader :status, :verification_id, :credentials_valid, :event,
                  :project, :receiver, :error

      def initialize(attributes = {})
        @success = attributes[:success] == true
        @status = safe_string(attributes[:status], 64)
        @verification_id = optional_string(attributes[:verification_id], 128)
        @credentials_valid = boolean_or_nil(attributes[:credentials_valid])
        @event = immutable_copy(hash_value(attributes[:event]))
        @project = optional_hash(attributes[:project])
        @receiver = optional_hash(attributes[:receiver])
        @error = optional_hash(attributes[:error])
        freeze
      end

      def success?
        @success
      end

      def to_h
        {
          "schema_version" => SCHEMA_VERSION,
          "success" => success?,
          "status" => status,
          "verification_id" => verification_id,
          "credentials_valid" => credentials_valid,
          "event_received" => event["received"] == true,
          "event" => event,
          "project" => project,
          "receiver" => receiver,
          "error" => error
        }
      end

      def to_json(*arguments)
        JSON.generate(to_h, *arguments)
      end

      private

      def optional_hash(value)
        value.is_a?(Hash) ? immutable_copy(value) : nil
      end

      def hash_value(value)
        value.is_a?(Hash) ? value : {}
      end

      def boolean_or_nil(value)
        [true, false].include?(value) ? value : nil
      end

      def optional_string(value, limit)
        return nil if value.nil?

        safe_string(value, limit)
      end

      def safe_string(value, limit)
        text = value.is_a?(String) || value.is_a?(Symbol) ? value.to_s : ""
        text = text.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "?")
        return text if text.bytesize <= limit

        text.byteslice(0, limit).to_s.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "?")
      rescue StandardError
        ""
      end

      def immutable_copy(value)
        copy = case value
               when Hash
                 value.each_with_object({}) do |(key, child), result|
                   result[safe_string(key, 64)] = immutable_copy(child)
                 end
               when Array
                 value.first(20).map { |child| immutable_copy(child) }
               when String
                 safe_string(value, 512)
               when NilClass, TrueClass, FalseClass, Numeric
                 value
               else
                 ""
               end
        copy.freeze
      end
    end
  end
end
