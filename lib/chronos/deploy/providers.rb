module Chronos
  module Deploy
    # Static integration fragments never interpolate customer input or credentials.
    module Providers
      PATHS = {
        "kamal" => ".kamal/hooks/post-deploy",
        "capistrano" => "lib/capistrano/tasks/chronos_deploy.rake",
        "github-actions" => "config/chronos/deploy/github-actions.steps.yml",
        "gitlab-ci" => "config/chronos/deploy/gitlab-ci.job.yml",
        "jenkins" => "config/chronos/deploy/jenkins.post.groovy",
        "azure-devops" => "config/chronos/deploy/azure-pipelines.steps.yml"
      }.freeze
      COMMAND = "bundle exec chronos deploy notify --on-error=warn".freeze
      MARKER = "# Chronos deploy template v1; credentials from environment only.\n".freeze
      INSTRUCTIONS = "# Supply CHRONOS_DEPLOY_ID and CHRONOS_DEPLOY_REVISION/VERSION " \
                     "from the actual publication.\n".freeze
      CAPISTRANO = <<-'RUBY'.freeze
      # Do not also load chronos/capistrano. Runs locally once after publication.
      namespace :chronos_cli do
        task :notify do
          if Rake::Task.task_defined?("chronos:notify_deploy")
            raise "Remove the duplicate chronos/capistrano integration"
          end
          system("bundle", "exec", "chronos", "deploy", "notify", "--on-error=warn")
        end
      end
      after "deploy:published", "chronos_cli:notify"
      RUBY
      BODIES = {
        "kamal" => "exec #{COMMAND}\n",
        "capistrano" => CAPISTRANO,
        "github-actions" => "# Merge into the real job after successful publication.\n" \
                            "- name: Notify Chronos\n  run: #{COMMAND}\n",
        "gitlab-ci" => "# Merge script into the successful deployment job; preserve artifact outputs.\n" \
                       ".chronos_deploy_notification:\n  script:\n    - #{COMMAND}\n",
        "jenkins" => "// Merge into existing post { success { ... } }; export actual publication outputs.\n" \
                     "sh '#{COMMAND}'\n",
        "azure-devops" => "# Merge after successful publication in the same job.\n" \
                          "- script: #{COMMAND}\n  displayName: Notify Chronos\n  condition: succeeded()\n"
      }.freeze

      def self.template(provider)
        comments = MARKER + INSTRUCTIONS
        comments = comments.gsub(/^#/, "//") if provider == "jenkins"
        shebang = provider == "kamal" ? "#!/bin/sh\n" : ""
        shebang + comments + BODIES.fetch(provider)
      end
    end
  end
end
