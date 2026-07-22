require "json"
require "rake"
require "chronos"

module Chronos
  # Installs explicit Rake commands supplied by the Chronos gem.
  #
  # @responsibility Register the integration verification task with deterministic JSON output.
  # @motivation Give Rails and plain Ruby operators one repeatable end-to-end credential check.
  # @limits It never reads environment variables, prints credentials, or modifies application data.
  # @collaborators Rake and Chronos.verify_integration.
  # @thread_safety Installation checks the process-global Rake registry and is intended for boot time.
  # @compatibility Rake versions compatible with Ruby 2.2.10 through Ruby 2.6.
  # @example
  #   require "chronos/rake_tasks"
  #   Chronos::RakeTasks.install
  # @errors Verification failures produce JSON and a nonzero process status.
  # @performance The task performs one explicit synchronous verification when invoked.
  module RakeTasks
    extend ::Rake::DSL

    TASK_NAME = "chronos:verify_integration".freeze

    def self.install(options = {})
      return false if ::Rake::Task.task_defined?(TASK_NAME)

      output = options[:output] || $stdout
      exiter = options[:exit] || proc { |status| exit(status) }
      prerequisites = ::Rake::Task.task_defined?("environment") ? ["environment"] : []

      desc "Send an identified fake error and verify Chronos credentials and ingestion"
      task TASK_NAME => prerequisites do
        result = Chronos.verify_integration
        output.puts(JSON.generate(result.to_h))
        exiter.call(1) unless result.success?
      end
      true
    end
  end
end
