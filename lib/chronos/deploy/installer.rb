require "fileutils"
require "tempfile"
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
        path = checked_path(root, relative)
        content = Providers.template(options[:provider])
        return "unchanged" if unchanged?(path, relative, content, options)
        raise Error, "Integration is missing; run install without --check." if options[:check]
        return "would_write_#{relative}" if options[:dry_run]

        write(root, relative, content, options)
        "created_#{relative}; merge after successful publication; supply explicit published identity and revision"
      rescue Errno::EEXIST, Errno::EACCES, Errno::ENOTDIR
        raise Error, "Integration destination is unavailable or changed; inspect it before retrying."
      end

      private

      def installation_root(options)
        root = File.expand_path(options[:root] || Dir.pwd)
        unless File.directory?(root) && !File.symlink?(root)
          raise Error, "Installation root must be an existing directory, not a symlink."
        end

        File.realpath(root)
      end

      def checked_path(root, relative)
        relative.split("/").inject(root) do |path, part|
          child = File.join(path, part)
          raise Error, "Installation path must not contain symlinks." if File.symlink?(child)

          child
        end
      end

      def unchanged?(path, relative, content, options)
        return false unless File.exist?(path)
        raise Error, "Integration destination must be a regular file." unless File.file?(path)
        return true if File.read(path) == content
        return false if options[:force] && !options[:check]

        proposed = content.lines.map { |line| "+#{line}" }.join
        raise Error.new("Existing integration differs; merge the proposed template or explicitly use --force.",
                        :path => relative,
                        :diff => "--- existing (content withheld for privacy)\n+++ proposed\n#{proposed}")
      end

      def write(root, relative, content, options)
        path = checked_path(root, relative)
        FileUtils.mkdir_p(File.dirname(path))
        temporary = Tempfile.new(".chronos-deploy-", File.dirname(path))
        begin
          temporary.write(content)
          temporary.chmod(options[:provider] == "kamal" ? 0o755 : 0o644)
          temporary.close
          checked_path(root, relative)
          if options[:force]
            File.rename(temporary.path, path)
          else
            # Exclusive creation: never replace a file created concurrently.
            File.link(temporary.path, path)
          end
        ensure
          temporary.close!
        end
      end
    end
  end
end
