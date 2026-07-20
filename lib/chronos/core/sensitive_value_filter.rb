module Chronos
  module Core
    # Redacts recognized secret and personal-data patterns inside strings.
    #
    # @responsibility Detect bounded sensitive value formats independently of hash-key policy.
    # @motivation Protect exception messages and allowlisted fields where no sensitive key exists.
    # @limits Detection is conservative, validates documents and cards, and does not cover every format.
    # @collaborators Sanitizer.
    # @thread_safety Immutable after construction and safe to share between capture calls.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   filter.call("person@example.com") #=> "[FILTERED_EMAIL]"
    # @errors Invalid encodings become a filtered placeholder.
    # @performance Applies a fixed set of regular expressions to each bounded string.
    class SensitiveValueFilter
      FILTERED = "[FILTERED]".freeze
      FILTERED_EMAIL = "[FILTERED_EMAIL]".freeze
      FILTERED_DOCUMENT = "[FILTERED_DOCUMENT]".freeze
      FILTERED_CARD = "[FILTERED_CARD]".freeze
      FILTERED_JWT = "[FILTERED_JWT]".freeze

      EMAIL_PATTERN = /\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b/i
      JWT_PATTERN = /\b[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/
      BEARER_PATTERN = /\bBearer\s+[^\s,;]+/i
      CPF_PATTERN = /\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b/
      CNPJ_PATTERN = %r{\b\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2}\b}
      IPV4_PATTERN = /\b(?:\d{1,3}\.){3}\d{1,3}\b/
      CARD_PATTERN = /\b(?:\d[ -]?){12,18}\d\b/

      def initialize(anonymize_ip)
        @anonymize_ip = anonymize_ip
        freeze
      end

      def call(value)
        result = safe_string(value)
        result = result.gsub(BEARER_PATTERN, "Bearer #{FILTERED}") if result =~ BEARER_PATTERN
        result = result.gsub(JWT_PATTERN, FILTERED_JWT) if result.count(".") >= 2
        result = result.gsub(EMAIL_PATTERN, FILTERED_EMAIL) if result.include?("@")
        result = redact_numeric_values(result) if result.count("0-9") >= 11
        @anonymize_ip && result.count(".") >= 3 ? anonymize_ipv4(result) : result
      rescue StandardError
        FILTERED
      end

      private

      def redact_numeric_values(value)
        result = redact_documents(value)
        value.count("0-9") >= 13 ? redact_cards(result) : result
      end

      def redact_cards(value)
        value.gsub(CARD_PATTERN) do |candidate|
          luhn_valid?(candidate) ? FILTERED_CARD : candidate
        end
      end

      def redact_documents(value)
        result = value.gsub(CNPJ_PATTERN) do |candidate|
          valid_cnpj?(candidate) ? FILTERED_DOCUMENT : candidate
        end
        result.gsub(CPF_PATTERN) do |candidate|
          valid_cpf?(candidate) ? FILTERED_DOCUMENT : candidate
        end
      end

      def valid_cpf?(candidate)
        digits = candidate.gsub(/\D/, "").chars.map(&:to_i)
        return false if digits.uniq.size == 1

        digits[9] == document_digit(digits.first(9), (2..10).to_a.reverse) &&
          digits[10] == document_digit(digits.first(10), (2..11).to_a.reverse)
      end

      def valid_cnpj?(candidate)
        digits = candidate.gsub(/\D/, "").chars.map(&:to_i)
        return false if digits.uniq.size == 1

        first_weights = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
        second_weights = [6] + first_weights
        digits[12] == document_digit(digits.first(12), first_weights) &&
          digits[13] == document_digit(digits.first(13), second_weights)
      end

      def document_digit(digits, weights)
        remainder = digits.each_with_index.inject(0) do |sum, (digit, index)|
          sum + (digit * weights[index])
        end % 11
        remainder < 2 ? 0 : 11 - remainder
      end

      def luhn_valid?(candidate)
        digits = candidate.gsub(/\D/, "").chars.map(&:to_i)
        return false unless digits.length.between?(13, 19)

        sum = digits.reverse.each_with_index.inject(0) do |total, (digit, index)|
          doubled = index.odd? ? digit * 2 : digit
          total + (doubled > 9 ? doubled - 9 : doubled)
        end
        (sum % 10).zero?
      end

      def anonymize_ipv4(value)
        value.gsub(IPV4_PATTERN) do |candidate|
          octets = candidate.split(".").map(&:to_i)
          octets.all? { |octet| octet.between?(0, 255) } ? "#{octets[0, 3].join('.')}.0" : candidate
        end
      end

      def safe_string(value)
        value.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "�")
      rescue StandardError
        FILTERED
      end
    end
  end
end
