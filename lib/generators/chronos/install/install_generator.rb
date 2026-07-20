require "rails/generators"

module Chronos
  module Generators
    # Generates the explicit Chronos initializer for legacy Rails applications.
    #
    # @responsibility Copy one documented initializer into config/initializers.
    # @motivation Keep credentials explicit and avoid automatic environment scanning.
    # @limits It does not modify routes, application classes, or Gemfiles.
    # @collaborators Rails::Generators::Base file-copy API.
    # @thread_safety Generator instances are used serially by the Rails command.
    # @compatibility Rails generator APIs available in Rails 4.2 through Rails 5.2.
    # @example
    #   rails generate chronos:install
    # @errors Existing-file conflict handling is delegated to Rails generators.
    # @performance Copies one small text file.
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def create_initializer
        copy_file "chronos.rb", "config/initializers/chronos.rb"
      end
    end
  end
end
