require "strscan"

module Chronos
  module Core
    # @responsibility Mask SQL literals before truncation and reject incomplete or ambiguous lexical input.
    # Conservative lexical validation is not a dialect-complete SQL parser.
    class SqlLexer
      MAX_BYTES = 4096

      def initialize(sql, adapter = "")
        @sql = sql
        @postgres = adapter.to_s =~ /postgres/i
      end

      def call
        return nil unless @sql.is_a?(String) && @sql.valid_encoding? && @sql.bytesize <= MAX_BYTES

        @scanner = StringScanner.new(@sql)
        result = ""
        until @scanner.eos?
          token = next_token
          return nil if token.nil?

          result << token
        end
        result
      end

      def single_select?
        text = call
        return false unless text && text.lstrip =~ /\ASELECT\b/i

        text.sub(/;\s*\z/, "") !~ /;/
      end

      private

      def next_token
        return " " if @scanner.scan(/\s+|--[^\r\n]*|\#[^\r\n]*/)
        return block_comment if @scanner.peek(2) == "/*"
        return quoted if ["'", '"', "`"].include?(@scanner.peek(1))
        return dollar_literal if @scanner.check(/\$(?:[A-Za-z_][A-Za-z0-9_]*)?\$/)

        @scanner.getch
      end

      def block_comment
        text = @scanner.scan(%r{/\*.*?\*/}m)
        return nil unless text
        return nil if text.start_with?("/*!", "/*M!") || text[2...-2].include?("/*")

        " "
      end

      def quoted
        quote = @scanner.peek(1)
        delimiter = Regexp.escape(quote)
        pattern = /#{delimiter}(?:#{delimiter * 2}|[^#{delimiter}\\])*#{delimiter}/m
        text = @scanner.scan(pattern)
        return nil unless text
        return "?" if quote == "'" || (quote == '"' && !@postgres)

        identifier = text[1...-1]
        identifier =~ /\A[A-Za-z_][A-Za-z0-9_$]*\z/ ? text : "?"
      end

      def dollar_literal
        delimiter = @scanner.scan(/\$(?:[A-Za-z_][A-Za-z0-9_]*)?\$/)
        @scanner.scan_until(/#{Regexp.escape(delimiter)}/m) ? "?" : nil
      end
    end
  end
end
