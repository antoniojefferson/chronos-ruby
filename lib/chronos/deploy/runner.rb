require "logger"
require "chronos"
require "chronos/deploy/configuration"

module Chronos
  module Deploy
    # @responsibility Execute the existing deploy or receipt API with bounded transport and guaranteed close.
    # One explicit operation through the existing agent, always closed on exit.
    class Runner
      def call(command, values, timeout)
        Configuration.validate!(values, command)
        begin
          configure(values, timeout, command)
          outcome = if command == "verify"
                      Chronos.verify_integration
                    else
                      Chronos.notify_deploy({:deploy_id => values["deploy_id"], :revision => values["revision"],
                                             :version => values["version"]}, timeout)
                    end
        ensure
          closed = Chronos.close(timeout)
        end
        command == "notify" ? outcome == true && closed != false : outcome
      end

      private

      def configure(values, timeout, command)
        Chronos.configure do |config|
          values.each do |key, value|
            attribute = key == "version" ? "app_version" : key
            config.public_send("#{attribute}=", value) unless value.nil?
          end
          config.logger = Logger.new(File::NULL)
          config.timeout = timeout
          config.open_timeout = timeout
          config.max_retries = 0
          config.backlog_size = 0
          config.dependency_reporting = false if command == "verify"
        end
      end
    end
  end
end
