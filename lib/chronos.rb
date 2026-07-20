require "chronos/version"
require "chronos/errors"
require "chronos/configuration"
require "chronos/core"
require "chronos/application"
require "chronos/ports"
require "chronos/adapters"
require "chronos/internal"
require "chronos/core/notice"
require "chronos/core/backtrace_parser"
require "chronos/core/exception_cause_collector"
require "chronos/core/runtime_info"
require "chronos/core/notice_builder"
require "chronos/core/sensitive_value_filter"
require "chronos/core/sanitizer"
require "chronos/core/safe_serializer"
require "chronos/core/payload_serializer"
require "chronos/ports/transport"
require "chronos/internal/safe_logger"
require "chronos/internal/bounded_queue"
require "chronos/internal/worker_pool"
require "chronos/adapters/net_http_transport"
require "chronos/application/capture_exception"
require "chronos/agent"

# Framework-independent public facade for the Chronos Ruby agent.
#
# @responsibility Configure the agent and expose its small lifecycle API.
# @motivation Give applications a stable entry point while internals evolve.
# @limits Version 0.1 captures Ruby exceptions only; integrations arrive later.
# @collaborators Configuration and Agent.
# @thread_safety Agent replacement and lookup are protected by a mutex.
# @compatibility Ruby 2.2.10 through Ruby 2.6.
# @example
#   Chronos.configure do |config|
#     config.project_id = "project-id"
#     config.project_key = "project-key"
#     config.host = "https://chronos.example.com"
#   end
#   Chronos.notify(RuntimeError.new("failed"))
module Chronos
  @mutex = Mutex.new
  @agent = nil

  class << self
    def configure
      configuration = Configuration.new
      yield configuration if block_given?
      agent = Agent.new(configuration.snapshot)
      previous = nil
      @mutex.synchronize do
        previous = @agent
        @agent = agent
      end
      previous.close if previous
      configuration
    end

    def notify(exception, context = {})
      agent = current_agent
      agent ? agent.notify(exception, context) : false
    rescue StandardError
      false
    end

    def notify_sync(exception, context = {})
      agent = current_agent
      agent ? agent.notify_sync(exception, context) : false
    rescue StandardError
      false
    end

    def configured?
      !current_agent.nil?
    end

    def flush(timeout = Agent::DEFAULT_FLUSH_TIMEOUT)
      agent = current_agent
      agent ? agent.flush(timeout) : true
    rescue StandardError
      false
    end

    def close(timeout = Agent::DEFAULT_FLUSH_TIMEOUT)
      agent = @mutex.synchronize do
        current = @agent
        @agent = nil
        current
      end
      agent ? agent.close(timeout) : true
    rescue StandardError
      false
    end

    private

    def current_agent
      @mutex.synchronize { @agent }
    end
  end
end
