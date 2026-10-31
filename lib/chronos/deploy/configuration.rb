require "yaml"
require "uri"
require "chronos/deploy/error"

module Chronos
  module Deploy
    # @responsibility Validate and resolve public options, canonical ENV and legacy aliases.
    # Resolves explicit CLI configuration without booting an application or agent.
    class Configuration
      FIELDS = %w(project_id project_key host environment service_name deploy_id revision version).freeze
      ALIASES = {"environment" => "DEPLOY_ENVIRONMENT", "service_name" => "SERVICE_NAME",
                 "deploy_id" => "DEPLOY_ID", "revision" => "GIT_SHA", "version" => "APP_VERSION"}.freeze
      HOST_ERROR = "Host must be an absolute HTTPS URL without credentials, query or fragment.".freeze

      def self.read(options, env)
        root = File.realpath(File.expand_path(options[:root] || Dir.pwd))
        public_values = read_public(root)
        values = FIELDS.each_with_object({}) do |field, result|
          result[field] = resolve(field, options, env, public_values)
        end
        values["host"] ||= "https://chronosmonitor.com.br"
        validate_host!(values["host"])
        values
      rescue Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES
        raise Error, "Configuration root or file is unavailable; check --root and permissions."
      end

      def self.read_public(root)
        path = File.join(root, "config/chronos-deploy.yml")
        if File.symlink?(File.join(root, "config")) || File.symlink?(path)
          raise Error, "Configuration path must not contain symlinks."
        end
        return {} unless File.exist?(path)
        raise Error, "Public configuration must be a regular file." unless File.file?(path)
        raise Error, "Public configuration exceeds 64 KiB." if File.size(path) > 65_536

        parsed = YAML.safe_load(File.read(path))
        values = parsed.nil? ? {} : parsed
        raise ArgumentError unless values.is_a?(Hash) && (values.keys - (FIELDS - ["project_key"])).empty?

        values.each_value { |value| validate_text!(value) }
        values
      end

      def self.resolve(field, options, env, public_values)
        prefix = %w(revision version).include?(field) ? "CHRONOS_DEPLOY_" : "CHRONOS_"
        primary = env["#{prefix}#{field.upcase}"]
        alternate = env[ALIASES[field]] if ALIASES[field]
        if primary && alternate && primary != alternate
          raise Error, "Conflicting canonical and alias environment variables; keep only one source."
        end

        value = options[field.to_sym] || primary || alternate || public_values[field]
        validate_text!(value)
        value
      end

      def self.validate_text!(value)
        raise ArgumentError unless value.nil? || value.is_a?(String)
        return if value.nil?
        return if value.valid_encoding? && value.encoding.ascii_compatible? && !value.match(/[[:cntrl:]]/)

        raise Error, "Configuration values must be text without control characters."
      end

      def self.validate_host!(host)
        uri = URI.parse(host)
        valid = uri.scheme == "https" && uri.host && !uri.userinfo && !uri.query && !uri.fragment
        raise Error, HOST_ERROR unless valid
      rescue URI::InvalidURIError
        raise Error, HOST_ERROR
      end

      def self.validate!(values, command)
        required = %w(project_id project_key environment)
        required << "deploy_id" if command != "verify"
        missing = required.select { |field| values[field].to_s.strip.empty? }
        raise Error.new("Supply the required configuration fields.", :missing_fields => missing) unless missing.empty?

        validate_release!(values) unless command == "verify"
        %w(environment service_name deploy_id revision version).each do |field|
          if values[field] && values[field].bytesize > 128
            raise Error, "Deployment metadata exceeds the 128-byte protocol limit."
          end
        end
        true
      end

      def self.validate_release!(values)
        return unless values["revision"].to_s.strip.empty? && values["version"].to_s.strip.empty?

        raise Error, "Supply the revision or version of the published artifact."
      end
    end
  end
end
