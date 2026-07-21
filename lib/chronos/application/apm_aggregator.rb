module Chronos
  module Application
    # Aggregates bounded request, query, job, and external HTTP observations into metric batches.
    #
    # @responsibility Maintain statistics, histograms, breakdown, and local query signals.
    # @motivation Avoid one network event per observation while retaining diagnostic value.
    # @limits Percentiles and heavy correlation remain server-side; state is process-local.
    # @collaborators CaptureTelemetry and immutable Chronos configuration.
    # @thread_safety A mutex protects groups, request trackers, counters, and drains.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; independent of Rails.
    # @example
    #   aggregator.record("request", payload, context)
    #   batches = aggregator.flush
    # @errors Invalid observations are ignored and never escape to the application.
    # @performance Group, transaction, query, bucket, and batch counts are strictly bounded.
    class ApmAggregator
      include ApmErrorClassifier

      METRIC_TYPES = %w(request query job external_http).freeze
      def initialize(config)
        @config = config
        @mutex = Mutex.new
        @groups = {}
        @transactions = {}
        @observations = 0
        @dropped_groups = 0
      end

      def record(event_type, payload = {}, context = {})
        return [] unless @config.apm_enabled

        @mutex.synchronize do
          type = event_type.to_s
          data = hash(payload)
          execution = hash(context)
          observe_component(type, data, execution)
          add_metric(type, data, execution) if aggregate_metric?(type, data)
          @observations += 1 if aggregate_metric?(type, data)
          @observations >= @config.apm_flush_count ? drain_locked : []
        end
      rescue StandardError
        []
      end

      def flush
        @mutex.synchronize { drain_locked }
      rescue StandardError
        []
      end

      def diagnostics
        @mutex.synchronize do
          {
            "groups" => @groups.length, "dropped_groups" => @dropped_groups,
            "transactions" => @transactions.length,
            "tracked_queries" => @transactions.values.inject(0) do |total, transaction|
              total + transaction["queries"].length
            end
          }
        end
      end

      private

      def aggregate_metric?(type, payload)
        METRIC_TYPES.include?(type) && !(type == "request" && payload["kind"].to_s == "view")
      end

      def add_metric(type, payload, context)
        dimensions = dimensions_for(type, payload)
        key = metric_key(type, dimensions)
        aggregate = @groups[key]
        unless aggregate
          if @groups.length >= @config.apm_max_groups
            @dropped_groups += 1
            return
          end
          aggregate = Core::MetricAggregate.new(type, dimensions, @config.apm_histogram_buckets)
          @groups[key] = aggregate
        end
        duration = non_negative(payload["duration_ms"] || payload[:duration_ms])
        status = ["request", "external_http"].include?(type) ? payload["status"] || payload[:status] : nil
        signals = signals_for(type, payload, context, duration)
        breakdown = breakdown_for(type, payload, context, duration)
        aggregate.observe(
          duration, error?(type, payload), breakdown, signals, status
        )
      end

      def observe_component(type, payload, context)
        return if type == "job"

        trace_id = trace_id(context)
        return if trace_id.empty?

        transaction = transaction_for(trace_id)
        return unless transaction

        category = component_category(type, payload)
        return observe_query(transaction, payload) if type == "query" && category.nil?
        return unless category

        transaction["breakdown_ms"][category] ||= 0.0
        transaction["breakdown_ms"][category] += non_negative(payload["duration_ms"] || payload[:duration_ms])
        observe_query(transaction, payload) if type == "query"
      end

      def transaction_for(trace_id)
        existing = @transactions[trace_id]
        return existing if existing
        return nil if @transactions.length >= @config.apm_max_groups

        @transactions[trace_id] = {"breakdown_ms" => {}, "signals" => {}, "queries" => {}}
      end

      def observe_query(transaction, payload)
        fingerprint = (payload["fingerprint"] || payload[:fingerprint]).to_s
        return if fingerprint.empty?

        queries = transaction["queries"]
        return unless queries.key?(fingerprint) || queries.length < @config.apm_max_queries_per_request

        queries[fingerprint] ||= 0
        queries[fingerprint] += 1
        count = queries[fingerprint]
        slow = non_negative(payload["duration_ms"]) >= @config.apm_slow_query_threshold_ms
        increment_signal(transaction, "slow_query") if slow
        increment_signal(transaction, "repeated_query") if count > 1
        increment_signal(transaction, "possible_n_plus_one") if count == @config.apm_n_plus_one_threshold
      end

      def breakdown_for(type, payload, context, duration)
        explicit = hash(payload["breakdown_ms"] || payload[:breakdown_ms]).dup
        if type == "request"
          transaction = @transactions.delete(trace_id(context))
          explicit = merge_numeric(explicit, transaction && transaction["breakdown_ms"])
          accounted = explicit.values.inject(0.0) { |total, value| total + non_negative(value) }
          explicit["application"] = [duration - accounted, 0.0].max
        elsif type == "query"
          explicit["database"] = duration
        elsif type == "job"
          explicit["queue"] = non_negative(payload["queue_latency_ms"] || payload[:queue_latency_ms])
          explicit["application"] = duration
        end
        explicit
      end

      def signals_for(type, payload, context, duration)
        return request_signals(context) if type == "request"
        return query_signals(payload, duration) if type == "query"

        {}
      end

      def request_signals(context)
        transaction = @transactions[trace_id(context)]
        transaction ? transaction["signals"].dup : {}
      end

      def query_signals(payload, duration)
        signals = {}
        signals["slow_query"] = 1 if duration >= @config.apm_slow_query_threshold_ms
        signals["long_transaction"] = 1 if long_transaction?(payload, duration)
        error_class = (payload["error_class"] || payload[:error_class]).to_s
        signals["connection_error"] = 1 if error_class =~ /Connection|NoDatabase|Adapter/i
        signals["deadlock"] = 1 if error_class =~ /Deadlock/i
        signals
      end

      def long_transaction?(payload, duration)
        operation = (payload["operation"] || payload[:operation]).to_s
        name = (payload["name"] || payload[:name]).to_s
        transaction = operation == "BEGIN" || operation == "COMMIT" || name =~ /TRANSACTION/i
        transaction && duration >= @config.apm_long_transaction_threshold_ms
      end

      def dimensions_for(type, payload)
        names = case type
                when "request" then %w(route method)
                when "query" then %w(adapter operation table fingerprint normalized_query name cached role shard source)
                when "job" then %w(kind class queue status)
                when "external_http" then %w(host method)
                else []
                end
        names.each_with_object({}) do |name, result|
          value = payload[name] || payload[name.to_sym]
          next if value.nil? || value.to_s.empty?

          result[name] = dimension_value(type, name, value)
        end
      end

      def dimension_value(type, name, value)
        return value == true if name == "cached"
        return value.to_i if type == "request" && name == "status"

        text = value.to_s
        text = normalize_route(text) if name == "route"
        text.bytesize > 512 ? text.byteslice(0, 512) : text
      end

      def normalize_route(route)
        route.split("/").map do |segment|
          segment =~ /\A\d+\z/ || segment =~ /\A[0-9a-f]{8}-[0-9a-f-]{27,}\z/i ? ":id" : segment
        end.join("/")
      end

      def metric_key(type, dimensions)
        type + "|" + dimensions.keys.sort.map { |key| "#{key}=#{dimensions[key]}" }.join("|")
      end

      def component_category(type, payload)
        return "database" if type == "query"
        return "view" if type == "request" && payload["kind"].to_s == "view"
        return "cache" if type == "cache"
        return "queue" if type == "job"
        return "external_http" if type == "external_http"

        nil
      end

      def trace_id(context)
        (context["trace_id"] || context[:trace_id]).to_s
      end

      def increment_signal(transaction, name)
        transaction["signals"][name] ||= 0
        transaction["signals"][name] += 1
      end

      def merge_numeric(left, right)
        hash(right).each do |key, value|
          left[key.to_s] ||= 0.0
          left[key.to_s] += non_negative(value)
        end
        left
      end

      def drain_locked
        metrics = @groups.values.map(&:to_h)
        if metrics.empty?
          @transactions = {}
          return []
        end

        dropped = @dropped_groups
        @groups = {}
        @transactions = {}
        @observations = 0
        @dropped_groups = 0
        batches = []
        metrics.each_slice(@config.apm_batch_size) do |slice|
          batches << {"metrics" => slice, "dropped_groups" => batches.empty? ? dropped : 0}
        end
        batches
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
