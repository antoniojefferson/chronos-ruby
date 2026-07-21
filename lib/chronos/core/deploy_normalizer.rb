require "securerandom"
require "uri"

module Chronos
  module Core
    # Normalizes explicit deployment metadata into the versioned deploy payload.
    #
    # @responsibility Validate required deploy identity and bound every public API field.
    # @motivation Deployment commands need predictable safe input independent of frameworks.
    # @limits It does not inspect Git, environment variables, credentials, or deployment systems.
    # @collaborators Chronos.notify_deploy, CorrelationContext, and Configuration::Snapshot.
    # @thread_safety Stateless apart from immutable configuration and an injected ID generator.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   DeployNormalizer.new(config).call(:revision => "abc", :version => "1.2.3")
    # @errors Missing environment or both revision/version raise ArgumentError for the agent to contain.
    # @performance Constant work over nine bounded scalar fields.
    class DeployNormalizer
      def initialize(config, options = {})
        @config = config
        @id_generator = options[:id_generator] || proc { SecureRandom.uuid }
      end

      def call(attributes = {})
        values = string_hash(attributes)
        payload = {
          "deploy_id" => deploy_id(values["deploy_id"] || @config.deploy_id),
          "environment" => bounded(values["environment"] || @config.environment, 128),
          "revision" => bounded(values["revision"] || @config.revision, 128),
          "version" => bounded(values["version"] || @config.app_version, 128),
          "repository" => repository(values["repository"]),
          "actor" => bounded(values["actor"], 128),
          "service" => bounded(values["service"] || @config.service_name, 128),
          "region" => bounded(values["region"] || @config.region, 128),
          "instance" => bounded(values["instance"] || @config.instance_id, 128)
        }
        validate!(payload)
        payload
      end

      private

      def validate!(payload)
        raise ArgumentError, "deploy environment is required" if payload["environment"].to_s.empty?
        return unless payload["revision"].to_s.empty? && payload["version"].to_s.empty?

        raise ArgumentError, "deploy revision or version is required"
      end

      def generated_id
        value = bounded(@id_generator.call, 128)
        raise ArgumentError, "deploy ID is required" if value.to_s.empty?

        value
      end

      def deploy_id(value)
        normalized = bounded(value, 128)
        normalized.to_s.empty? ? generated_id : normalized
      end

      def repository(value)
        text = bounded(value, 512)
        return nil if text.nil?

        scp = text.match(/\A[^@]+@([^:]+):(.+)\z/)
        return bounded("#{scp[1]}/#{scp[2]}", 512) if scp

        uri = URI.parse(text)
        return bounded("#{uri.host}#{uri.path}", 512) if uri.host
        return bounded(uri.path, 512) unless uri.path.to_s.empty?

        nil
      rescue StandardError
        nil
      end

      def string_hash(value)
        raise ArgumentError, "deploy attributes must be a Hash" unless value.is_a?(Hash)

        value.each_with_object({}) do |(key, child), result|
          result[key.to_s] = child if key.is_a?(String) || key.is_a?(Symbol)
        end
      end

      def bounded(value, limit)
        return nil if value.nil?
        return nil unless scalar?(value)

        text = value.to_s
        text = text.scrub("?") if text.respond_to?(:scrub)
        text.bytesize > limit ? text.byteslice(0, limit) : text
      rescue StandardError
        nil
      end

      def scalar?(value)
        value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(Numeric)
      end
    end
  end
end
