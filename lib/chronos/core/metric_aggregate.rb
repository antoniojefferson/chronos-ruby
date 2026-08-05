module Chronos
  module Core
    # Accumulates one bounded APM metric group and serializes aggregate statistics.
    #
    # @responsibility Track counts, errors, durations, histogram, breakdown, signals, and diagnostics.
    # @motivation Keep numerical accumulation separate from grouping and request correlation.
    # @limits It does not choose dimensions, retain observations, or calculate exact percentiles.
    # @collaborators ApmAggregator and immutable histogram boundaries.
    # @thread_safety Mutable by design; callers must synchronize access.
    # @compatibility Ruby 2.2.10 through Ruby 2.6.
    # @example
    #   metric.observe(12.0, false, {"database" => 3.0}, {}, :diagnostics => [])
    # @errors Non-numeric durations become zero and never escape.
    # @performance Memory is fixed by the configured histogram boundary count.
    class MetricAggregate
      BREAKDOWN_CATEGORIES = %w(database view external_http cache queue application unknown).freeze
      DIAGNOSTIC_SEVERITIES = %w(error warning info suggestion).freeze
      MAX_DIAGNOSTICS = 20

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
        @diagnostics = {}
        @severity_counts = {}
        @query_analysis = nil
      end

      def observe(duration, error, breakdown, signals, options = {})
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
        add_status(options[:status])
        add_diagnostics(options[:diagnostics])
        retain_query_analysis(options[:query_analysis])
        self
      end

      def to_h
        {
          "metric_type" => @metric_type, "dimensions" => @dimensions,
          "count" => @count, "error_count" => @error_count,
          "error_rate" => (@error_count.to_f / @count).round(6),
          "duration_ms" => duration_summary, "percentiles_ms" => percentiles, "histogram" => histogram,
          "breakdown_ms" => rounded_hash(@breakdown), "signals" => @signals,
          "status_codes" => @status_codes, "severity_counts" => @severity_counts,
          "diagnostics" => @diagnostics.values, "query_analysis" => @query_analysis || {}
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

      def add_diagnostics(values)
        Array(values).first(MAX_DIAGNOSTICS).each do |diagnostic|
          data = hash(diagnostic)
          severity = data["severity"].to_s
          next unless DIAGNOSTIC_SEVERITIES.include?(severity)

          @severity_counts[severity] ||= 0
          @severity_counts[severity] += 1
          key = diagnostic_key(data)
          existing = @diagnostics[key]
          if existing
            existing["count"] += 1
          elsif @diagnostics.length < MAX_DIAGNOSTICS
            @diagnostics[key] = data.merge("count" => 1)
          end
        end
      end

      def diagnostic_key(data)
        evidence = hash(data["evidence"])
        [data["code"], data["severity"], evidence["table"], Array(evidence["columns"]).join(",")].join("|")
      end

      def retain_query_analysis(value)
        return unless value.is_a?(Hash) && !value.empty?
        return if @query_analysis && analysis_score(@query_analysis) >= analysis_score(value)

        @query_analysis = value.reject { |key, _child| key.to_s == "diagnostics" }
      end

      def analysis_score(value)
        data = hash(value)
        inspection = hash(data["inspection"] || data[:inspection])
        score = inspection.empty? ? 0 : 1
        score += 1 unless Array(inspection["indexes"] || inspection[:indexes]).empty?
        score += 1 unless hash(inspection["statistics"] || inspection[:statistics]).empty?
        score += 1 unless hash(inspection["plan"] || inspection[:plan]).empty?
        score
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

      def percentiles
        {"p50" => percentile(0.50), "p95" => percentile(0.95), "p99" => percentile(0.99)}
      end

      def percentile(ratio)
        target = (@count * ratio).ceil
        accumulated = 0
        @buckets.each_with_index do |count, index|
          accumulated += count
          return (@boundaries[index] || @max).to_f.round(3) if accumulated >= target
        end
        @max.to_f.round(3)
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
