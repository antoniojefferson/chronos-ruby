module Chronos
  module Core
    # Accumulates one bounded APM metric group and serializes aggregate statistics.
    #
    # @responsibility Track counts, errors, durations, histogram, breakdown, and signals.
    # @motivation Keep numerical accumulation separate from grouping and request correlation.
    # @limits It does not choose dimensions, retain observations, or calculate percentiles.
    # @collaborators ApmAggregator and immutable histogram boundaries.
    # @thread_safety Mutable by design; callers must synchronize access.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   metric.observe(12.0, false, {"database" => 3.0}, {})
    # @errors Non-numeric durations become zero and never escape.
    # @performance Memory is fixed by the configured histogram boundary count.
    class MetricAggregate
      BREAKDOWN_CATEGORIES = %w(database view external_http cache queue application unknown).freeze

      def initialize(metric_type, dimensions, boundaries)
        @metric_type = metric_type
        @dimensions = dimensions
        @boundaries = boundaries
        @count = 0
        @error_count = 0
        @total = 0.0
        @min = nil
        @max = nil
        @buckets = Array.new(boundaries.length + 1, 0)
        @breakdown = {}
        @signals = {}
        @status_codes = {}
      end

      def observe(duration, error, breakdown, signals, status = nil)
        value = non_negative(duration)
        @count += 1
        @error_count += 1 if error
        @total += value
        @min = value if @min.nil? || value < @min
        @max = value if @max.nil? || value > @max
        bucket = @boundaries.index { |boundary| value <= boundary }
        @buckets[bucket || @boundaries.length] += 1
        add_breakdown(breakdown)
        add_signals(signals)
        add_status(status)
        self
      end

      def to_h
        {
          "metric_type" => @metric_type, "dimensions" => @dimensions,
          "count" => @count, "error_count" => @error_count,
          "error_rate" => (@error_count.to_f / @count).round(6),
          "duration_ms" => duration_summary, "histogram" => histogram,
          "breakdown_ms" => rounded_hash(@breakdown), "signals" => @signals,
          "status_codes" => @status_codes
        }
      end

      private

      def add_breakdown(values)
        hash(values).each do |category, duration|
          name = BREAKDOWN_CATEGORIES.include?(category.to_s) ? category.to_s : "unknown"
          @breakdown[name] ||= 0.0
          @breakdown[name] += non_negative(duration)
        end
      end

      def add_signals(values)
        hash(values).each do |name, count|
          @signals[name.to_s] ||= 0
          @signals[name.to_s] += count.to_i
        end
      end

      def add_status(status)
        return if status.nil?

        key = status.to_i.to_s
        @status_codes[key] ||= 0
        @status_codes[key] += 1
      end

      def duration_summary
        {
          "total" => @total.round(3), "min" => @min.round(3), "max" => @max.round(3),
          "average" => (@total / @count).round(3)
        }
      end

      def histogram
        @buckets.each_with_index.map do |count, index|
          {"le" => @boundaries[index] || "+Inf", "count" => count}
        end
      end

      def rounded_hash(values)
        values.each_with_object({}) { |(key, value), result| result[key] = value.round(3) }
      end

      def non_negative(value)
        number = value.to_f
        number < 0.0 ? 0.0 : number
      rescue StandardError
        0.0
      end

      def hash(value)
        value.is_a?(Hash) ? value : {}
      end
    end
  end
end
