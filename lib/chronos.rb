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
require "chronos/core/correlation_context"
require "chronos/core/deploy_normalizer"
require "chronos/core/payload_serializer"
require "chronos/core/telemetry_event"
require "chronos/core/sql_normalizer"
require "chronos/core/metric_aggregate"
require "chronos/core/cache_normalizer"
require "chronos/ports/transport"
require "chronos/ports/context_store"
require "chronos/internal/safe_logger"
require "chronos/internal/bounded_queue"
require "chronos/internal/memory_backlog"
require "chronos/internal/worker_pool"
require "chronos/adapters/net_http_transport"
require "chronos/adapters/thread_local_context_store"
require "chronos/core/breadcrumb"
require "chronos/application/retry_policy"
require "chronos/application/circuit_breaker"
require "chronos/application/remote_configuration"
require "chronos/application/ignore_policy"
require "chronos/application/delivery_pipeline"
require "chronos/application/capture_exception"
require "chronos/application/apm_error_classifier"
require "chronos/application/apm_aggregator"
require "chronos/application/dependency_reporter"
require "chronos/application/capture_telemetry"
require "chronos/agent"
require "chronos/observability_facade"
require "chronos/integrations"
require "chronos/integrations/rack"
require "chronos/integrations/rack/middleware"

# Framework-independent public facade for the Chronos Ruby agent.
#
# @responsibility Configure the agent and expose its small lifecycle API.
# @motivation Give applications a stable entry point while internals evolve.
# @limits Rails integration remains optional and must be loaded through chronos/rails.
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
module Chronos # rubocop:disable Metrics/ModuleLength
  extend ObservabilityFacade

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

    def with_context(context = {})
      agent = current_agent
      return yield unless agent

      agent.with_context(context) { yield }
    end

    def add_breadcrumb(attributes = {})
      agent = current_agent
      agent ? agent.add_breadcrumb(attributes) : false
    rescue StandardError
      false
    end

    def record_event(event_type, payload = {}, context = {})
      agent = current_agent
      agent ? agent.record_event(event_type, payload, context) : false
    rescue StandardError
      false
    end

    def record_event_once(key, event_type, payload = {}, context = {})
      agent = current_agent
      agent ? agent.record_event_once(key, event_type, payload, context) : false
    rescue StandardError
      false
    end

    def apm_integration_options
      agent = current_agent
      agent ? agent.apm_integration_options : {:enabled => false}
    rescue StandardError
      {:enabled => false}
    end

    # Returns only trace/request identifiers for optional process-boundary adapters.
    def propagation_context
      agent = current_agent
      agent ? agent.propagation_context : {}
    rescue StandardError
      {}
    end

    def notify_once(exception, context = {})
      agent = current_agent
      agent ? agent.notify_once(exception, context) : false
    rescue StandardError
      false
    end

    def ignore_if(&block)
      agent = current_agent
      agent ? agent.ignore_if(&block) : false
    rescue StandardError
      false
    end

    def rails_integration_options(environment = nil, console = false)
      agent = current_agent
      agent ? agent.rails_integration_options(environment, console) : {:enabled => false}
    rescue StandardError
      {:enabled => false}
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

require "chronos/rails" if defined?(::Rails::Railtie)
