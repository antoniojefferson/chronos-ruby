require "logger"
require "tmpdir"
require "rails"
require "action_controller/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "chronos/rails"
require "rack/mock"
require_relative "../../spec/support/fake_transport"

ENV["RAILS_ENV"] = "production"
ENV["DATABASE_URL"] = "sqlite3::memory:"
transport = FakeTransport.new
configurations = 0
# Test-only injection: exercise the real agent and integrations without contacting a SaaS endpoint.
Chronos::Adapters::NetHttpTransport.define_singleton_method(:new) do |*_arguments|
  configurations += 1
  transport
end

module TransitionalSmoke
  # Small real application shared by the three pinned Rails 7 fixtures.
  class Application < Rails::Application
    config.eager_load = false
    config.secret_key_base = "synthetic-fixture-secret-not-for-production"
    config.logger = Logger.new(File::NULL)
    config.hosts.clear
    config.active_job.queue_adapter = :inline
    config.action_dispatch.show_exceptions = false
    initializer "smoke.chronos", :before => "chronos.install", :after => :load_config_initializers do
      Chronos.configure do |settings|
        settings.project_id = "synthetic-project"
        settings.project_key = "synthetic-key"
        settings.environment = "production"
        settings.logger = Rails.logger
        settings.dependency_reporting = false
      end
    end
  end

  # Exercises controller notifications and ordinary SQL instrumentation.
  class SmokeController < ActionController::Base
    def index
      ActiveRecord::Base.connection.select_value("SELECT 'synthetic-private-value' AS value")
      render :plain => "ok"
    end
  end

  # Exercises the real Active Job serialization and execution hooks.
  class SmokeJob < ActiveJob::Base
    def perform
      true
    end
  end
end

begin
  TransitionalSmoke::Application.initialize!
  Rails.application.routes.draw { get "/ok", :to => "transitional_smoke/smoke#index" }
  raise "agent initialized more than once" unless configurations == 1
  raise "deploy emitted during boot" if transport.events.any? { |event| event.body.include?('"event_type":"deploy"') }
  chain = Sidekiq.default_configuration.client_middleware
  raise "Rails did not install Sidekiq" unless chain.exists?(Chronos::Integrations::Sidekiq::ClientMiddleware)
  raise "Sidekiq installed twice" if Chronos::Integrations::Sidekiq.install(Sidekiq)
  job = {"class" => "SyntheticWorker", "queue" => "default", "jid" => "synthetic-jid", "args" => ["unchanged"]}
  chain.invoke(Object, job, "default", nil) { true }
  raise "Sidekiq propagation missing" unless job["chronos"] && job["args"] == ["unchanged"]
  ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
  response = Rack::MockRequest.new(Rails.application).get("/ok")
  raise "request failed: #{response.status}" unless response.status == 200
  TransitionalSmoke::SmokeJob.perform_now
  error = RuntimeError.new("synthetic reporter error")
  Rails.error.report(error, :handled => true, :severity => :warning)
  raise "reporter hook missing or deduplication failed" unless Chronos.notify_once(error) == false
  raise "flush failed" unless Chronos.flush(2)
  envelopes = transport.events.map { |event| JSON.parse(event.body) }
  exceptions = envelopes.select { |event| event["event_type"] == "exception" }
  raise "error reporter duplicate or missing" unless exceptions.length == 1
  metrics = envelopes.select { |event| event["event_type"] == "metric_batch" }
                     .flat_map { |event| event["payload"].fetch("metrics") }
  types = metrics.map { |metric| metric["metric_type"] }
  raise "request/job/query telemetry missing" unless (%w(request query job) - types).empty?
  request_count = metrics.select { |metric| metric["metric_type"] == "request" }.sum { |metric| metric["count"] }
  raise "request captured more than once" unless request_count == 1
  raise "SQL literal leaked" if envelopes.to_s.include?("synthetic-private-value")
  load File.expand_path("../../test/smoke_deploy_rails.rb", __dir__)
  raise "generator reinitialized agent" unless configurations == 1
  puts "Rails #{Rails.version} / Ruby #{RUBY_VERSION} smoke passed"
ensure
  Chronos.close(2)
end
