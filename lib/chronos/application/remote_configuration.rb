module Chronos
  module Application
    # Runtime policy restricted to server-authorized scalar options.
    #
    # @responsibility Validate and apply bounded remote delivery controls.
    # @motivation Let operators reduce telemetry safely without redeploying an application.
    # @limits It cannot change host, credentials, TLS, code, or regular expressions.
    # @collaborators Configuration snapshot, CaptureException, and DeliveryPipeline.
    # @thread_safety A mutex protects immutable state replacements.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   remote.apply("sampling_rate" => 0.5, "kill_switch" => false)
    # @errors Invalid documents are ignored and return false.
    # @performance Validation is bounded by configured document and list limits.
    class RemoteConfiguration
      SUPPORTED_EVENT_TYPES = ["exception"].freeze
      MAX_IGNORED_FINGERPRINTS = 100
      MAX_FINGERPRINT_BYTES = 256
      MIN_PAYLOAD_SIZE = 256

      attr_reader :ignored_fingerprints

      def initialize(config, options = {})
        @config = config
        @random = options[:random] || proc { rand }
        @mutex = Mutex.new
        @local_event_types = allowed_event_types(config.enabled_event_types)
        @values = {
          "sampling_rate" => config.sampling_rate.to_f,
          "enabled_event_types" => @local_event_types,
          "max_payload_size" => config.max_payload_size,
          "ignored_fingerprints" => [],
          "send_interval" => 0.0,
          "kill_switch" => false
        }
        @ignored_fingerprints = [].freeze
      end

      def apply(document)
        normalized = normalize(document)
        return false unless normalized

        @mutex.synchronize do
          @values = @values.merge(normalized)
          @ignored_fingerprints = @values["ignored_fingerprints"].dup.freeze
        end
        true
      rescue StandardError
        false
      end

      def capture?(event_type, fingerprint = nil)
        values = snapshot
        return false if values["kill_switch"]
        return false unless values["enabled_event_types"].include?(event_type.to_s)
        return false if fingerprint && values["ignored_fingerprints"].include?(fingerprint.to_s)

        rate = values["sampling_rate"]
        rate >= 1.0 || (rate > 0.0 && @random.call.to_f < rate)
      end

      def enabled_event?(event_type)
        snapshot["enabled_event_types"].include?(event_type.to_s)
      end

      def ignored_fingerprint?(fingerprint)
        snapshot["ignored_fingerprints"].include?(fingerprint.to_s)
      end

      def sampling_rate
        snapshot["sampling_rate"]
      end

      def max_payload_size
        snapshot["max_payload_size"]
      end

      def send_interval
        snapshot["send_interval"]
      end

      def kill_switch?
        snapshot["kill_switch"]
      end

      def to_h
        snapshot
      end

      private

      def normalize(document)
        return nil unless document.is_a?(Hash)

        normalized = {}
        document.each do |key, value|
          name = key.to_s
          next unless @values.key?(name)

          normalized_value = normalize_value(name, value)
          return nil if normalized_value.nil? && value != false
          normalized[name] = normalized_value
        end
        normalized.empty? ? nil : normalized
      end

      def normalize_value(name, value)
        case name
        when "sampling_rate"
          bounded_rate(value)
        when "enabled_event_types"
          normalize_event_types(value)
        when "max_payload_size"
          normalize_payload_size(value)
        when "ignored_fingerprints"
          normalize_fingerprints(value)
        when "send_interval"
          normalize_send_interval(value)
        when "kill_switch"
          value if [true, false].include?(value)
        end
      end

      def bounded_rate(value)
        return nil unless value.is_a?(Numeric) && value >= 0.0 && value <= @config.sampling_rate

        value.to_f
      end

      def normalize_event_types(value)
        return nil unless value.is_a?(Array) && value.all? { |item| item.is_a?(String) }

        allowed_event_types(value)
      end

      def allowed_event_types(values)
        supported = values.map(&:to_s).select { |value| SUPPORTED_EVENT_TYPES.include?(value) }
        supported.select { |value| local_event_types.include?(value) }.uniq.freeze
      end

      def local_event_types
        @local_event_types || SUPPORTED_EVENT_TYPES
      end

      def normalize_payload_size(value)
        return nil unless value.is_a?(Integer) && value >= MIN_PAYLOAD_SIZE && value <= @config.max_payload_size

        value
      end

      def normalize_fingerprints(value)
        return nil unless value.is_a?(Array) && value.length <= MAX_IGNORED_FINGERPRINTS
        return nil unless value.all? { |item| item.is_a?(String) && item.bytesize <= MAX_FINGERPRINT_BYTES }

        value.map(&:dup).freeze
      end

      def normalize_send_interval(value)
        return nil unless value.is_a?(Numeric) && value >= 0.0 && value <= @config.max_remote_send_interval

        value.to_f
      end

      def snapshot
        @mutex.synchronize do
          @values.each_with_object({}) do |(key, value), copy|
            copy[key] = value.is_a?(Array) ? value.dup : value
          end
        end
      end
    end
  end
end
