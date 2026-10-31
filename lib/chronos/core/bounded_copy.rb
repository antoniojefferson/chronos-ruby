module Chronos
  module Core
    # @responsibility Copy untrusted diagnostic trees without cycles, unbounded recursion or caller mutation.
    # Ruby 2.2-compatible structural budgets apply before immutable event construction.
    class BoundedCopy
      MAX_DEPTH = 10
      MAX_ITEMS = 100
      MAX_NODES = 2_000
      MAX_STRING_BYTES = 8192

      def call(value)
        copy(value, 0, :nodes => 0, :seen => {}.compare_by_identity)
      end

      private

      def copy(value, depth, state)
        state[:nodes] += 1
        return "<node limit reached>".freeze if state[:nodes] > MAX_NODES
        return "<maximum depth reached>".freeze if depth >= MAX_DEPTH
        return container(value, depth, state) if value.is_a?(Hash) || value.is_a?(Array)

        scalar(value)
      end

      def container(value, depth, state)
        return "<circular reference>".freeze if state[:seen][value]

        state[:seen][value] = true
        result = value.is_a?(Hash) ? copy_hash(value, depth, state) : copy_array(value, depth, state)
        state[:seen].delete(value)
        result.freeze
      end

      def copy_hash(value, depth, state)
        result = {}
        value.each do |key, child|
          break if result.length >= MAX_ITEMS || state[:nodes] >= MAX_NODES

          result[copy(key, depth + 1, state)] = copy(child, depth + 1, state)
        end
        result
      end

      def copy_array(value, depth, state)
        result = []
        value.each do |child|
          break if result.length >= MAX_ITEMS || state[:nodes] >= MAX_NODES

          result << copy(child, depth + 1, state)
        end
        result
      end

      def scalar(value)
        case value
        when String
          return "<string limit reached>".freeze if value.bytesize > MAX_STRING_BYTES

          value.dup.freeze
        when NilClass, TrueClass, FalseClass, Symbol, Numeric
          value
        else
          "<#{value.class.name}>".freeze
        end
      end
    end
  end
end
