module Chronos
  module Application
    # Builds one bounded inventory from already loaded runtime components.
    #
    # @responsibility Report loaded gems and runtime/framework versions once per agent.
    # @motivation Dependency context aids diagnosis without attaching the bundle to every error.
    # @limits It does not read lockfiles, environment variables, gem paths, or open DB connections.
    # @collaborators RubyGems loaded specs and immutable Chronos configuration.
    # @thread_safety A mutex guarantees at-most-once collection across concurrent first events.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; all framework detection is optional.
    # @example
    #   payload = DependencyReporter.new(config).call
    # @errors Detection failures yield omitted fields and never escape.
    # @performance Runs once and visits at most the configured number of loaded specs.
    class DependencyReporter
      def initialize(config, options = {})
        @config = config
        @loaded_specs = options[:loaded_specs] || proc { Gem.loaded_specs }
        @constants = options[:constants] || {}
        @mutex = Mutex.new
        @reported = false
        @release_override = nil
      end

      def reset(release = nil)
        @mutex.synchronize do
          @release_override = bounded(release, 128)
          @reported = false
        end
        true
      rescue StandardError
        false
      end

      def call
        @mutex.synchronize do
          return nil if @reported || !@config.dependency_reporting

          @reported = true
          build_payload
        end
      rescue StandardError
        nil
      end

      private

      def build_payload
        payload = {
          "dependencies" => dependencies,
          "ruby" => {
            "version" => bounded(RUBY_VERSION, 64), "engine" => bounded(ruby_engine, 64),
            "platform" => bounded(RUBY_PLATFORM, 128)
          },
          "rails" => detected("rails") { rails_version },
          "web_server" => detected("web_server") { web_server },
          "database_adapter" => detected("database_adapter") { database_adapter },
          "sidekiq" => detected("sidekiq") { sidekiq_version },
          "release" => @release_override || bounded(@config.app_version.to_s, 128)
        }
        payload.delete_if do |key, value|
          !["dependencies", "ruby"].include?(key) && value.to_s.empty?
        end
        payload
      end

      def dependencies
        specs = @loaded_specs.call
        values = specs.respond_to?(:values) ? specs.values : []
        values.first(@config.dependency_max_items).sort_by { |spec| spec.name.to_s }.map do |spec|
          {"name" => bounded(spec.name.to_s, 128), "version" => bounded(spec.version.to_s, 64)}
        end
      rescue StandardError
        []
      end

      def detected(name)
        explicit = @constants[name]
        return bounded(explicit.to_s, 128) unless explicit.nil?

        bounded(yield.to_s, 128)
      rescue StandardError
        ""
      end

      def rails_version
        defined?(::Rails) && ::Rails.respond_to?(:version) ? ::Rails.version.to_s : loaded_version("rails")
      end

      def sidekiq_version
        defined?(::Sidekiq::VERSION) ? ::Sidekiq::VERSION.to_s : loaded_version("sidekiq")
      end

      def web_server
        return "Puma" if defined?(::Puma)
        return "Unicorn" if defined?(::Unicorn)
        return "Passenger" if defined?(::PhusionPassenger)
        return "WEBrick" if defined?(::WEBrick)

        ""
      end

      def database_adapter
        names = loaded_spec_names
        return "PostgreSQL" if names.include?("pg")
        return "MySQL" if names.include?("mysql2")
        return "SQLite" if names.include?("sqlite3")

        ""
      end

      def loaded_version(name)
        specs = @loaded_specs.call
        spec = specs[name] || specs[name.to_sym] if specs.respond_to?(:[])
        spec ? spec.version.to_s : ""
      rescue StandardError
        ""
      end

      def loaded_spec_names
        specs = @loaded_specs.call
        specs.respond_to?(:keys) ? specs.keys.map(&:to_s) : []
      rescue StandardError
        []
      end

      def ruby_engine
        defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"
      end

      def bounded(value, limit)
        text = value.to_s
        text = text.scrub("?") if text.respond_to?(:scrub)
        text.bytesize > limit ? text.byteslice(0, limit) : text
      rescue StandardError
        ""
      end
    end
  end
end
