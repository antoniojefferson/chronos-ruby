require "chronos/deploy/error"
require "chronos/deploy/providers"

module Chronos
  module Deploy
    # @responsibility Generate provider fragments while preserving existing customer integrations.
    # Explicit, idempotent generation of static fragments below a caller-selected root.
    class Installer
      PATHS = Providers::PATHS

      def install(options)
        raise Error, "Use --check without --force." if options[:force] && options[:check]

        relative = PATHS[options[:provider]]
        raise Error, "Choose a supported --provider; see chronos --help." unless relative

        root = installation_root(options)
        require "chronos/deploy/secure_directory"
        SecureDirectory.with_root(root) do |directory|
          install_into(directory, relative, options)
        end
      rescue Errno::EEXIST, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP
        raise Error, "Integration destination is unavailable or changed; inspect it before retrying."
      end

      private

      def install_into(directory, relative, options)
        content = Providers.template(options[:provider])
        existing = directory.with_parent(relative, false) { |parent, name| parent && parent.read(name) }
        return "unchanged" if unchanged?(existing, relative, content, options)
        raise Error, "Integration is missing; run install without --check." if options[:check]
        return "would_write_#{relative}" if options[:dry_run]

        directory.with_parent(relative, true) do |parent, name|
          current = parent.read(name)
          unless unchanged?(current, relative, content, options)
            parent.write(name, content, options[:provider] == "kamal", options[:force])
          end
        end
        "created_#{relative}; merge after successful publication; supply explicit published identity and revision"
      end

      def installation_root(options)
        root = File.expand_path(options[:root] || Dir.pwd)
        unless File.directory?(root) && !File.symlink?(root)
          raise Error, "Installation root must be an existing directory, not a symlink."
        end

        root
      end

      def unchanged?(existing, relative, content, options)
        return false if existing.nil?
        return true if existing == content
        return false if options[:force] && !options[:check]

        proposed = content.lines.map { |line| "+#{line}" }.join
        raise Error.new("Existing integration differs; merge the proposed template or explicitly use --force.",
                        :path => relative,
                        :diff => "--- existing (content withheld for privacy)\n+++ proposed\n#{proposed}")
      end
    end
  end
end
