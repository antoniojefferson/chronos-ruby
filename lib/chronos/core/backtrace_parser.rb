module Chronos
  module Core
    # Parses CRuby and common JRuby backtrace lines without rejecting unknown input.
    #
    # @responsibility Convert backtrace strings into bounded structured frames.
    # @motivation Give the SaaS stable fields for display and grouping.
    # @limits It does not read source files or collect code hunks.
    # @collaborators NoticeBuilder.
    # @thread_safety Stateless and safe to reuse between threads.
    # @compatibility CRuby 2.2.10 through 2.6 and common JRuby line formats.
    # @example
    #   parser.call(["app/job.rb:12:in `call'"])
    # @performance Linear in the number of frames, capped by max_frames.
    class BacktraceParser
      DEFAULT_MAX_FRAMES = 200

      def initialize(root_directory, max_frames = DEFAULT_MAX_FRAMES)
        @root_directory = expand_root(root_directory)
        @max_frames = max_frames
      end

      def call(lines)
        Array(lines).first(@max_frames).map { |line| parse(line) }
      end

      private

      def parse(line)
        text = safe_string(line)
        match = text.match(/\A(.+?):(\d+)(?::in [`'](.*)['`])?\z/)
        return unknown_frame(text) unless match

        file = normalize_file(match[1])
        {
          "file" => file,
          "line" => match[2].to_i,
          "function" => match[3],
          "in_app" => in_app?(file)
        }
      rescue StandardError
        unknown_frame(safe_string(line))
      end

      def unknown_frame(line)
        {"file" => line, "line" => nil, "function" => nil, "in_app" => false}
      end

      def normalize_file(file)
        return file unless @root_directory && file.start_with?(@root_directory + File::SEPARATOR)

        file[(@root_directory.length + 1)..-1]
      end

      def in_app?(file)
        return false unless @root_directory
        return true unless file.start_with?(File::SEPARATOR)

        file.start_with?(@root_directory + File::SEPARATOR)
      end

      def expand_root(root)
        root && File.expand_path(root.to_s)
      rescue StandardError
        nil
      end

      def safe_string(value)
        value.to_s
      rescue StandardError
        "<unreadable backtrace>"
      end
    end
  end
end
