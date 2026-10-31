require "rails/generators"
require "chronos/deploy/installer"

module Chronos
  module Generators
    module Deploy
      # @responsibility Delegate explicit Rails generation to the shared deploy installer.
      # Rails adapter for the same explicit installer used by the CLI.
      class InstallGenerator < ::Rails::Generators::Base
        namespace "chronos:deploy:install"
        class_option :provider, :type => :string, :required => true
        class_option :dry_run, :type => :boolean, :default => false
        class_option :check, :type => :boolean, :default => false
        class_option :force, :type => :boolean, :default => false

        def install_deploy
          result = Chronos::Deploy::Installer.new.install(
            :root => destination_root, :provider => options[:provider],
            :dry_run => options[:dry_run], :check => options[:check], :force => options[:force]
          )
          say result
        end
      end
    end
  end
end
