require "optparse"
require "json"
require "chronos/version"
require "chronos/deploy/configuration"
require "chronos/deploy/installer"

module Chronos
  # @responsibility Parse explicit deployment commands and return sanitized operational results.
  # Local command parser; operational responses use a versioned, allowlisted JSON envelope.
  class CLI
    HELP = "chronos deploy notify|verify|diagnose --offline|install --provider NAME\n" \
           "Options: --root PATH, --project-id ID, --environment NAME, --service-name NAME,\n" \
           "--deploy-id ID, --revision SHA, --version VERSION, --host URL, --timeout SECONDS,\n" \
           "--json, --on-error=warn, --dry-run, --check, --force\n" \
           "Project key: CHRONOS_PROJECT_KEY only. No application boot.\n" \
           "Exit: 0 confirmed/local success; 1 invalid configuration; 2 unconfirmed delivery; 3 internal failure.\n" \
           "warn returns 0 for unconfirmed delivery, retaining success=false. Never retry blindly.\n".freeze

    def initialize(output = $stdout, env = ENV)
      @output = output
      @env = env
    end

    def run(arguments)
      args = arguments.dup
      return local(HELP) if help?(args)
      return local(Chronos::VERSION) if args == ["--version"]
      raise ArgumentError unless args.shift == "deploy"

      command = args.shift
      raise ArgumentError unless %w(notify verify diagnose install).include?(command)

      options = parse_options(args)
      return local(HELP) if options[:help]
      raise ArgumentError unless args.empty? && options[:timeout] > 0 && options[:timeout] <= 60

      validate_options!(command, options)
      execute(command, options)
    rescue Deploy::Error => e
      result(false, "invalid_configuration_or_usage", 1, e.details.merge(:message => e.message))
    rescue OptionParser::ParseError, ArgumentError, Psych::Exception
      result(false, "invalid_configuration_or_usage", 1,
             :message => "Invalid options or public configuration; see chronos --help.")
    rescue StandardError
      result(false, "internal_failure", 3)
    end

    private

    def help?(args)
      args.empty? || %w(help --help -h).include?(args.first)
    end

    def parse_options(args)
      options = {:timeout => 5.0}
      parser = OptionParser.new
      %w(root project-id environment service-name deploy-id revision version host provider).each do |name|
        parser.on("--#{name} VALUE") { |value| options[name.tr("-", "_").to_sym] = value }
      end
      %w(json offline dry-run check force).each do |name|
        parser.on("--#{name}") { options[name.tr("-", "_").to_sym] = true }
      end
      parser.on("--timeout SECONDS", Float) { |value| options[:timeout] = value }
      parser.on("--on-error POLICY", %w(warn fail)) { |value| options[:on_error] = value }
      parser.on("--help") { options[:help] = true }
      parser.parse!(args)
      options
    end

    def execute(command, options)
      return result(true, Deploy::Installer.new.install(options), 0) if command == "install"

      values = Deploy::Configuration.read(options, @env)
      if command == "diagnose"
        raise Deploy::Error, "Diagnose requires --offline." unless options[:offline]

        Deploy::Configuration.validate!(values, "notify")
        return result(true, "local_configuration_only", 0,
                      :message => "Local configuration is complete; credentials and delivery were not authenticated.")
      end
      deliver(command, values, options)
    end

    def deliver(command, values, options)
      require "chronos/deploy/runner"
      delivery = Deploy::Runner.new.call(command, values, options[:timeout])
      success = command == "verify" ? delivery.success? : delivery == true
      details = command == "verify" ? {:verification_status => delivery.status} : {}
      code = success || options[:on_error] == "warn" ? 0 : 2
      result(success, success ? "confirmed" : "unconfirmed", code, details)
    end

    def validate_options!(command, options)
      common = [:root, :json, :help]
      operational = [:project_id, :environment, :service_name, :deploy_id, :revision, :version, :host, :timeout]
      allowed = command == "install" ? common + [:provider, :dry_run, :check, :force, :timeout] : common + operational
      allowed += [:offline] if command == "diagnose"
      allowed += [:on_error] if %w(notify verify).include?(command)
      unless (options.keys - allowed).empty?
        raise Deploy::Error, "Option does not apply to this command; see chronos --help."
      end
      raise Deploy::Error, "Use --check without --force." if options[:force] && options[:check]
    end

    def local(message)
      @output.puts(message)
      0
    end

    def result(success, state, code, details = {})
      data = {:schema_version => 1, :success => success, :state => state}.merge(details)
      # JSON is the default operational format; --json makes that intent explicit.
      @output.puts(JSON.generate(data))
      code
    end
  end
end
