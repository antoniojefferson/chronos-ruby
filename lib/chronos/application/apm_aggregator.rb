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
    class ApmAggregator # rubocop:disable Metrics/ClassLength
      include ApmErrorClassifier

      METRIC_TYPES = %w(request query job external_http).freeze
      QUERY_ERROR_SIGNALS = {
        "connection_error" => /Connection|NoDatabase|Adapter/i,
        "deadlock" => /Deadlock/i,
        "query_timeout" => /StatementTimeout|QueryCanceled|QueryTimeout|Timeout/i,
        "pool_timeout" => /ConnectionTimeout|PoolTimeout/i,
        "lock_timeout" => /LockWaitTimeout|LockTimeout/i,
        "constraint_violation" => /RecordNotUnique|NotNullViolation|ForeignKeyViolation|InvalidForeignKey|Constraint/i
      }.freeze
      SIGNAL_DIAGNOSTICS = {
        "slow_query" => ["warning", "performance", "Query duration reached the slow threshold"].freeze,
        "long_transaction" => ["warning", "transaction", "Transaction SQL reached the long threshold"].freeze,
        "connection_error" => ["error", "connection", "Database connection failed"].freeze,
        "deadlock" => ["error", "locking", "The database reported a deadlock"].freeze,
        "query_timeout" => ["error", "timeout", "The database query timed out"].freeze,
        "pool_timeout" => ["error", "connection_pool", "Database connection-pool checkout timed out"].freeze,
        "lock_timeout" => ["error", "locking", "The database lock wait timed out"].freeze,
        "constraint_violation" => ["error", "constraint", "The database rejected a constraint"].freeze
      }.freeze
      def initialize(config, options = {})
        @config = config
        @clock = options[:clock] || proc { Time.now.to_f }
        @mutex = Mutex.new
        @groups = {}
        @transactions = {}
        @observations = 0
        @dropped_groups = 0
        @dropped_trace_trackers = 0
        @expired_trace_trackers = 0
        @dropped_query_fingerprints = 0
      end

      def record(event_type, payload = {}, context = {})
        return [] unless @config.apm_enabled

        @mutex.synchronize do
          expire_transactions
          type = event_type.to_s
          data = hash(payload)
          execution = hash(context)
          correlation = observe_component(type, data, execution)
          add_metric(type, data, execution, correlation) if aggregate_metric?(type, data)
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
            "dropped_trace_trackers" => @dropped_trace_trackers,
            "expired_trace_trackers" => @expired_trace_trackers,
            "dropped_query_fingerprints" => @dropped_query_fingerprints,
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

      def add_metric(type, payload, context, correlation)
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
        signals = signals_for(type, payload, context, duration, correlation)
        diagnostics = diagnostics_for(type, payload, context, signals, correlation)
        breakdown = breakdown_for(type, payload, context, duration)
        aggregate.observe(
          duration, error?(type, payload), breakdown, signals,
          :status => status, :diagnostics => diagnostics,
          :query_analysis => type == "query" ? hash(payload["analysis"] || payload[:analysis]) : {}
        )
      end

      def observe_component(type, payload, context)
        return {} if type == "job"

        trace_id = trace_id(context)
        return {} if trace_id.empty?

        transaction = transaction_for(trace_id)
        return {} unless transaction

        transaction["last_seen_at"] = now

        category = component_category(type, payload)
        return observe_query(transaction, payload) if type == "query" && category.nil?
        return {} unless category

        transaction["breakdown_ms"][category] ||= 0.0
        transaction["breakdown_ms"][category] += non_negative(payload["duration_ms"] || payload[:duration_ms])
        return observe_query(transaction, payload) if type == "query"

        {}
      end

      def transaction_for(trace_id)
        existing = @transactions[trace_id]
        return existing if existing
        if @transactions.length >= @config.apm_max_groups
          @dropped_trace_trackers += 1
          return nil
        end

        @transactions[trace_id] = {
          "breakdown_ms" => {}, "signals" => {}, "queries" => {}, "diagnostics" => [],
          "last_seen_at" => now
        }
      end

      def observe_query(transaction, payload)
        fingerprint = (payload["fingerprint"] || payload[:fingerprint]).to_s
        return {} if fingerprint.empty?

        queries = transaction["queries"]
        unless queries.key?(fingerprint) || queries.length < @config.apm_max_queries_per_request
          @dropped_query_fingerprints += 1
          return {}
        end

        queries[fingerprint] ||= 0
        queries[fingerprint] += 1
        count = queries[fingerprint]
        slow = non_negative(payload["duration_ms"]) >= @config.apm_slow_query_threshold_ms
        increment_signal(transaction, "slow_query") if slow
        current = {}
        if count > 1
          increment_signal(transaction, "repeated_query")
          current["repeated_query"] = 1
        end
        if n_plus_one_candidate?(payload) && count == @config.apm_n_plus_one_threshold
          increment_signal(transaction, "possible_n_plus_one")
          current["possible_n_plus_one"] = 1
        end
        {"signals" => current, "query_count" => count}
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

      def signals_for(type, payload, context, duration, correlation)
        return request_signals(context) if type == "request"
        return merge_integer_signals(query_signals(payload, duration), hash(correlation["signals"])) if type == "query"

        {}
      end

      def diagnostics_for(type, payload, context, signals, correlation)
        return request_diagnostics(context) if type == "request"
        return [] unless type == "query"

        analysis = hash(payload["analysis"] || payload[:analysis])
        result = Array(analysis["diagnostics"] || analysis[:diagnostics]).first(20)
        result += signal_diagnostics(signals, correlation)
        error_class = (payload["error_class"] || payload[:error_class]).to_s
        unless error_class.empty?
          result << diagnostic("query_execution_error", "error", "execution",
                               "The database query raised an exception", "error_class" => error_class[0, 128])
        end
        retain_transaction_diagnostics(context, result)
        result.first(20)
      end

      def signal_diagnostics(signals, correlation)
        result = signal_error_diagnostics(signals)
        if hash(correlation["signals"])["repeated_query"]
          result << diagnostic("repeated_query", "info", "query_pattern",
                               "The same query fingerprint repeated in one trace",
                               "occurrence" => correlation["query_count"])
        end
        if hash(correlation["signals"])["possible_n_plus_one"]
          result << diagnostic("possible_n_plus_one", "warning", "n_plus_one",
                               "Repeated SELECT reached the N+1 threshold",
                               "occurrence" => correlation["query_count"])
          item = diagnostic("n_plus_one_eager_loading", "suggestion", "n_plus_one",
                            "Review eager loading or batch loading for this query fingerprint")
          item["recommendation"] = "Use includes, preload, eager_load, or an equivalent bounded batch query " \
                                   "when semantics allow"
          result << item
        end
        result
      end

      def signal_error_diagnostics(signals)
        SIGNAL_DIAGNOSTICS.each_with_object([]) do |(code, values), result|
          result << diagnostic(code, values[0], values[1], values[2]) if signals[code]
        end
      end

      def diagnostic(code, severity, category, message, evidence = {})
        {"code" => code, "severity" => severity, "category" => category,
         "message" => message, "evidence" => evidence}
      end

      def retain_transaction_diagnostics(context, diagnostics)
        transaction = @transactions[trace_id(context)]
        return unless transaction

        diagnostics.each do |item|
          next if transaction["diagnostics"].any? { |existing| existing["code"] == item["code"] }
          transaction["diagnostics"] << item if transaction["diagnostics"].length < 20
        end
      end

      def request_diagnostics(context)
        transaction = @transactions[trace_id(context)]
        transaction ? transaction["diagnostics"].dup : []
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
        QUERY_ERROR_SIGNALS.each do |name, pattern|
          signals[name] = 1 if error_class =~ pattern
        end
        signals
      end

      def long_transaction?(payload, duration)
        operation = (payload["operation"] || payload[:operation]).to_s
        name = (payload["name"] || payload[:name]).to_s
        transaction = operation == "BEGIN" || operation == "COMMIT" || operation == "ROLLBACK" || name =~ /TRANSACTION/i
        measured = non_negative(payload["transaction_duration_ms"] || payload[:transaction_duration_ms] || duration)
        transaction && measured >= @config.apm_long_transaction_threshold_ms
      end

      def n_plus_one_candidate?(payload)
        operation = (payload["operation"] || payload[:operation]).to_s
        cached = payload.key?("cached") ? payload["cached"] : payload[:cached]
        operation == "SELECT" && cached != true
      end

      def merge_integer_signals(left, right)
        result = left.dup
        right.each { |key, value| result[key.to_s] = result.fetch(key.to_s, 0) + value.to_i }
        result
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
        return [] if metrics.empty?

        dropped = @dropped_groups
        @groups = {}
        @observations = 0
        @dropped_groups = 0
        tracking = {
          "active_traces" => @transactions.length,
          "dropped_trace_trackers" => @dropped_trace_trackers,
          "expired_trace_trackers" => @expired_trace_trackers,
          "dropped_query_fingerprints" => @dropped_query_fingerprints
        }
        @dropped_trace_trackers = 0
        @expired_trace_trackers = 0
        @dropped_query_fingerprints = 0
        batches = []
        metrics.each_slice(@config.apm_batch_size) do |slice|
          slice.first["tracking"] = batches.empty? ? tracking : empty_tracking
          batches << {"metrics" => slice, "dropped_groups" => batches.empty? ? dropped : 0}
        end
        batches
      end

      def expire_transactions
        threshold = now - @config.apm_trace_ttl_seconds.to_f
        expired = @transactions.keys.select { |key| @transactions[key]["last_seen_at"].to_f < threshold }
        expired.each { |key| @transactions.delete(key) }
        @expired_trace_trackers += expired.length
      end

      def empty_tracking
        {"active_traces" => @transactions.length, "dropped_trace_trackers" => 0,
         "expired_trace_trackers" => 0, "dropped_query_fingerprints" => 0}
      end

      def now
        @clock.call.to_f
      rescue StandardError
        Time.now.to_f
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
