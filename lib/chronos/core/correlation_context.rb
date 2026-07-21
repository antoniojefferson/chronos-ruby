module Chronos
  module Core
    # Builds the bounded release/deploy correlation shared by every event envelope.
    #
    # @responsibility Normalize release, revision, deploy, environment, service, region, and instance.
    # @motivation Give the SaaS stable before/after-deploy dimensions without integration-specific fields.
    # @limits Values come only from explicit configuration or caller overrides; no environment is scanned.
    # @collaborators PayloadSerializer, TelemetrySerializer, and Configuration::Snapshot.
    # @thread_safety Instances hold immutable configuration and calls allocate independent frozen hashes.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   CorrelationContext.new(config).call("revision" => "abc123")
    # @errors Unreadable optional values become nil and do not escape.
    # @performance Seven strings are copied with a fixed 128-byte maximum each.
    class CorrelationContext
      FIELDS = %w(release revision deploy_id environment service region instance).freeze

      def initialize(config)
        @config = config
      end

      def call(overrides = {})
        values = defaults.merge(string_hash(overrides))
        result = FIELDS.each_with_object({}) do |name, correlation|
          correlation[name.freeze] = bounded(values[name], 128)
        end
        result.each_value { |value| value.freeze if value }
        result.freeze
      rescue StandardError
        FIELDS.each_with_object({}) { |name, fallback| fallback[name] = nil }.freeze
      end

      private

      def defaults
        {
          "release" => @config.app_version, "revision" => @config.revision,
          "deploy_id" => @config.deploy_id, "environment" => @config.environment,
          "service" => @config.service_name, "region" => @config.region,
          "instance" => @config.instance_id
        }
      end

      def string_hash(value)
        return {} unless value.is_a?(Hash)

        value.each_with_object({}) do |(key, child), result|
          result[key.to_s] = child if key.is_a?(String) || key.is_a?(Symbol)
        end
      end

      def bounded(value, limit)
        return nil if value.nil?
        return nil unless value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(Numeric)

        text = value.to_s
        text = text.scrub("?") if text.respond_to?(:scrub)
        text = text.byteslice(0, limit) if text.bytesize > limit
        text
      rescue StandardError
        nil
      end
    end
  end
end
