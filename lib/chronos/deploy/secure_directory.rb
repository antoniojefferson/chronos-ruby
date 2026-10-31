require "fiddle/import"
require "securerandom"
require "chronos/deploy/error"

module Chronos
  module Deploy
    # @responsibility Anchor installer reads and writes to directory descriptors without following symlinks.
    # POSIX openat/mkdirat/linkat/renameat prevent parent-path replacement from redirecting writes.
    class SecureDirectory
      # Fixed POSIX entry points; no shell, dynamic symbol names, or user-provided native code.
      module Native
        extend Fiddle::Importer
        dlload Fiddle::Handle::DEFAULT
        extern "int openat(int, const char*, int, unsigned int)"
        extern "int mkdirat(int, const char*, unsigned int)"
        extern "int linkat(int, const char*, int, const char*, int)"
        extern "int renameat(int, const char*, int, const char*)"
        extern "int unlinkat(int, const char*, int)"
      end

      def self.with_root(root)
        raise Error, "Secure installation requires POSIX no-follow support." unless File.const_defined?(:NOFOLLOW)

        handle = File.open(root, File::RDONLY | File::NOFOLLOW | File::NONBLOCK)
        raise Error, "Installation root must be a directory." unless handle.stat.directory?

        yield new(handle)
      ensure
        handle.close if handle && !handle.closed?
      end

      def with_parent(relative, create)
        handles = []
        current = self
        parts = relative.split("/")
        parts[0...-1].each do |part|
          child = current.directory(part, create)
          return yield(nil, parts.last) unless child

          handles << child
          current = self.class.new(child)
        end
        yield current, parts.last
      ensure
        handles.reverse_each(&:close)
      end

      def initialize(handle)
        @handle = handle
      end

      def directory(name, create)
        file = open_file(name, File::RDONLY | File::NONBLOCK)
        if file.nil? && create
          status = Native.mkdirat(@handle.fileno, name, 0o755)
          check!(status) unless status.zero? || Fiddle.last_error == Errno::EEXIST::Errno
          file = open_file(name, File::RDONLY | File::NONBLOCK)
        end
        return nil unless file
        return file if file.stat.directory?

        file.close
        raise Error, "Installation parent must be a directory."
      end

      def read(name)
        file = open_file(name, File::RDONLY | File::NONBLOCK)
        return nil unless file

        begin
          raise Error, "Integration must be a regular file of at most 64 KiB." unless file.stat.file?

          content = file.read(65_537) || ""
          raise Error, "Integration must be a regular file of at most 64 KiB." if content.bytesize > 65_536

          content
        ensure
          file.close
        end
      end

      def write(name, content, executable, force)
        temporary = ".chronos-deploy-#{SecureRandom.hex(16)}"
        file = open_file(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600)
        raise Error, "Installation directory is unavailable." unless file

        begin
          file.write(content)
          file.chmod(executable ? 0o755 : 0o644)
          file.close
          if force
            check!(Native.renameat(@handle.fileno, temporary, @handle.fileno, name))
          else
            check!(Native.linkat(@handle.fileno, temporary, @handle.fileno, name, 0))
          end
        ensure
          file.close unless file.closed?
          Native.unlinkat(@handle.fileno, temporary, 0)
        end
      end

      private

      def open_file(name, flags, mode = 0)
        if name.empty? || name.include?("/") || name.include?("\0") || %w(. ..).include?(name)
          raise Error, "Unsafe installation path component."
        end

        descriptor = Native.openat(@handle.fileno, name, flags | File::NOFOLLOW, mode)
        return nil if descriptor < 0 && Fiddle.last_error == Errno::ENOENT::Errno

        check!(descriptor)
        file = File.for_fd(descriptor, (flags & File::WRONLY).zero? ? "r" : "w")
        file.close_on_exec = true
        file
      end

      def check!(status)
        return status if status >= 0

        raise Error, "Installation path changed, contains a symlink, or is unavailable; inspect it before retrying."
      end
    end
  end
end
