module Chronos
  # Public entry points for optional observability and deployment integrations.
  #
  # @responsibility Delegate dependency, cache, outbound HTTP, and deploy calls to the agent.
  # @motivation Keep the main public facade small while preserving one stable Chronos namespace.
  # @limits It installs only explicitly supplied Net::HTTP connections and never enables features.
  # @collaborators Chronos::Agent and Chronos::Integrations::NetHttp.
  # @thread_safety Agent access uses the facade's synchronized current_agent lookup.
  # @compatibility Ruby 2.2.10 through Ruby 2.6.
  # @example
  #   Chronos.instrument_net_http(Net::HTTP.new("api.example.com"))
  # @errors Integration failures return false or safe disabled options.
  # @performance Delegation is constant-time; dependency collection remains at-most-once.
  module ObservabilityFacade
    def report_dependencies
      agent = current_agent
      agent ? agent.report_dependencies : false
    rescue StandardError
      false
    end

    def notify_deploy(attributes = {}, timeout = Agent::DEFAULT_FLUSH_TIMEOUT)
      agent = current_agent
      agent ? agent.notify_deploy(attributes, timeout) : false
    rescue StandardError
      false
    end

    def external_http_integration_options
      agent = current_agent
      agent ? agent.external_http_integration_options : {:enabled => false}
    rescue StandardError
      {:enabled => false}
    end

    def cache_integration_options
      agent = current_agent
      agent ? agent.cache_integration_options : {:project_id => "", :key_mode => :none}
    rescue StandardError
      {:project_id => "", :key_mode => :none}
    end

    def instrument_net_http(connection, options = {})
      require "chronos/net_http"
      Integrations::NetHttp.install(connection, options.merge(:notifier => self))
    rescue StandardError
      false
    end
  end
end
