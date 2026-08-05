module Chronos
  module Rails
    # Converts public ActiveSupport notifications into bounded Chronos telemetry.
    #
    # @responsibility Subscribe once and normalize controller, view, SQL, mailer, job, and cache events.
    # @motivation Support Rails 4.2 and 5.2 through feature detection and public notification APIs.
    # @limits It never sends SQL text, binds, raw cache keys/values, mail bodies, or job arguments.
    # @collaborators ActiveSupport::Notifications and the Chronos facade.
    # @thread_safety Subscription registry is mutex-protected; callbacks own their state.
    # @compatibility ActiveSupport notification argument shapes from Rails 4.2 through 5.2.
    # @example
    #   Chronos::Rails::NotificationsSubscriber.new.install
    # @errors Subscriber failures are contained and never escape into Rails.
    # @performance Each notification builds a small allowlisted hash and queues asynchronously.
    class NotificationsSubscriber # rubocop:disable Metrics/ClassLength
      EVENTS = %w(
        process_action.action_controller render_template.action_view sql.active_record
        deliver.action_mailer perform.active_job cache_read.active_support
        cache_write.active_support cache_fetch_hit.active_support
      ).freeze

      @mutex = Mutex.new
      @installed_buses = {}

      class << self
        attr_reader :mutex, :installed_buses
      end

      def initialize(notifier = Chronos, notifications = nil, options = {})
        @notifier = notifier
        @notifications = notifications || active_support_notifications
        @sql_normalizer = Core::SqlNormalizer.new
        @query_analyzer = options[:query_analyzer] || Core::SqlQueryAnalyzer.new
        @query_inspector = options[:query_inspector] || default_query_inspector
        @query_inspection_mutex = Mutex.new
        @query_inspections = {}
        @query_analyses = {}
        @clock = options[:clock] || proc { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        @transaction_mutex = Mutex.new
        @transactions = {}
        cache_options = notifier.respond_to?(:cache_integration_options) ? notifier.cache_integration_options : {}
        @cache_normalizer = Core::CacheNormalizer.new(
          cache_options[:project_id].to_s, cache_options[:key_mode] || :none
        )
      end

      def install
        return false unless @notifications && @notifications.respond_to?(:subscribe)

        self.class.mutex.synchronize do
          return false if self.class.installed_buses[@notifications.object_id]

          event_names.each { |name| subscribe(name) }
          self.class.installed_buses[@notifications.object_id] = true
        end
        true
      rescue StandardError
        false
      end

      def handle(name, arguments)
        event = notification_event(name, arguments)
        dispatch(name, event[:payload], event[:duration_ms])
      rescue StandardError
        false
      end

      private

      def active_support_notifications
        return nil unless defined?(::ActiveSupport::Notifications)

        ::ActiveSupport::Notifications
      end

      def subscribe(name)
        @notifications.subscribe(name) { |*arguments| handle(name, arguments) }
      end

      def event_names
        return EVENTS if defined?(::ActiveJob)

        EVENTS.reject { |name| name == "perform.active_job" }
      end

      def notification_event(name, arguments)
        candidate = arguments.first
        if arguments.length == 1 && candidate.respond_to?(:payload)
          return {:payload => hash(candidate.payload), :duration_ms => candidate.duration.to_f}
        end

        started_at = arguments[1]
        finished_at = arguments[2]
        {
          :payload => hash(arguments[4]),
          :duration_ms => duration_ms(started_at, finished_at),
          :name => name
        }
      end

      def dispatch(name, payload, duration)
        case name
        when "process_action.action_controller" then process_action(payload, duration)
        when "render_template.action_view" then render_template(payload, duration)
        when "sql.active_record" then sql(payload, duration)
        when "deliver.action_mailer" then mailer(payload, duration)
        when "perform.active_job" then active_job(payload, duration)
        else cache(name, payload, duration)
        end
      end

      def process_action(payload, duration)
        capture_controller_exception(payload)
        data = {
          "kind" => "controller", "controller" => value(payload, :controller),
          "action" => value(payload, :action), "status" => value(payload, :status).to_i,
          "method" => value(payload, :method), "path" => query_free_path(value(payload, :path)),
          "route" => route(payload),
          "duration_ms" => duration, "parameters" => hash(value(payload, :params))
        }
        record_once("request", "request", data)
      end

      def render_template(payload, duration)
        data = {
          "kind" => "view", "template" => safe_basename(value(payload, :identifier)),
          "duration_ms" => duration
        }
        @notifier.record_event("request", data)
      end

      def sql(payload, duration)
        return false if query_inspection_suppressed?

        metadata = {
          :name => value(payload, :name), :cached => value(payload, :cached),
          :adapter => value(payload, :adapter), :connection => value(payload, :connection),
          :role => value(payload, :connection_role) || value(payload, :role),
          :shard => value(payload, :connection_shard) || value(payload, :shard),
          :exception_object => value(payload, :exception_object), :exception => value(payload, :exception)
        }
        metadata[:source] = sampled_query_source if duration >= slow_query_threshold
        data = @sql_normalizer.call(value(payload, :sql), metadata).merge("duration_ms" => duration)
        track_transaction(data, metadata[:connection])
        if query_analysis_options[:analysis_enabled]
          inspection = query_inspection(value(payload, :sql), data, metadata[:connection], duration)
          analysis = cached_query_analysis(data, inspection)
          data["analysis"] = analysis unless analysis.empty?
        end
        @notifier.record_event("query", data)
      end

      def cached_query_analysis(data, inspection)
        options = query_analysis_options
        fingerprint = data["fingerprint"].to_s
        @query_inspection_mutex.synchronize do
          existing = @query_analyses[fingerprint]
          return existing if existing && inspection.empty?
          return existing if existing && !hash(existing["inspection"]).empty?
          return {} unless existing || @query_analyses.length < options[:max_analyses]

          @query_analyses[fingerprint] = @query_analyzer.call(data, inspection)
        end
      rescue StandardError => error
        {"diagnostics" => [{"code" => "query_analysis_failed", "severity" => "error",
                            "category" => "analysis", "message" => "Normalized query analysis failed",
                            "evidence" => {"error_class" => safe_error_class(error)}}]}
      end

      def query_inspection(raw_sql, data, connection, duration)
        options = query_analysis_options
        return {} unless options[:inspection_enabled]
        return {} unless duration >= options[:min_duration_ms]
        return {} unless @query_inspector && Ports::QueryInspector.compatible?(@query_inspector)

        fingerprint = data["fingerprint"].to_s
        @query_inspection_mutex.synchronize do
          return @query_inspections[fingerprint] if @query_inspections.key?(fingerprint)
          return {} if @query_inspections.length >= options[:max_queries]

          @query_inspections[fingerprint] = @query_inspector.call(
            raw_sql, data, :connection => connection,
                           :statistics => options[:statistics_enabled], :plan => options[:plan_enabled]
          )
        end
      rescue StandardError => error
        {"errors" => [safe_error_class(error)]}
      end

      def query_analysis_options
        values = @notifier.respond_to?(:apm_integration_options) ? @notifier.apm_integration_options : {}
        {
          :analysis_enabled => values.fetch(:query_analysis_enabled, true) == true,
          :max_analyses => (values[:query_analysis_max_queries] || 100).to_i,
          :inspection_enabled => values[:query_inspection_enabled] == true,
          :statistics_enabled => values[:query_statistics_enabled] == true,
          :plan_enabled => values[:query_plan_enabled] == true,
          :min_duration_ms => (values[:query_inspection_min_duration_ms] || 500.0).to_f,
          :max_queries => (values[:query_inspection_max_queries] || 20).to_i,
          :transaction_tracking_enabled => values.fetch(:transaction_tracking_enabled, true) == true,
          :transaction_max_connections => (values[:transaction_max_connections] || 100).to_i,
          :transaction_ttl_seconds => (values[:transaction_ttl_seconds] || 60.0).to_f
        }
      rescue StandardError
        {:analysis_enabled => true, :max_analyses => 100,
         :inspection_enabled => false, :statistics_enabled => false,
         :plan_enabled => false, :min_duration_ms => 500.0, :max_queries => 20,
         :transaction_tracking_enabled => true, :transaction_max_connections => 100,
         :transaction_ttl_seconds => 60.0}
      end

      def track_transaction(data, connection)
        options = query_analysis_options
        return unless options[:transaction_tracking_enabled] && connection

        operation = data["operation"].to_s
        normalized = data["normalized_query"].to_s
        key = connection.object_id.to_s
        current_time = monotonic_now
        @transaction_mutex.synchronize do
          expire_tracked_transactions(current_time, options[:transaction_ttl_seconds])
          details = {
            :operation => operation, :normalized => normalized, :current_time => current_time,
            :max_connections => options[:transaction_max_connections]
          }
          update_transaction_state(data, key, details)
        end
      rescue StandardError
        nil
      end

      def update_transaction_state(data, key, details)
        operation = details[:operation]
        normalized = details[:normalized]
        current_time = details[:current_time]
        state = @transactions[key]
        return start_tracked_transaction(key, state, current_time, details) if transaction_start?(operation, normalized)
        return unless state

        if operation == "SAVEPOINT"
          state["depth"] += 1
        elsif operation == "RELEASE" || normalized =~ /\AROLLBACK\s+TO\b/i
          state["depth"] = [state["depth"] - 1, 1].max
        elsif ["COMMIT", "ROLLBACK"].include?(operation)
          finish_tracked_transaction(data, key, state, current_time)
          return
        end
        state["last_seen_at"] = current_time
      end

      def transaction_start?(operation, normalized)
        operation == "BEGIN" || normalized =~ /\ASTART\s+TRANSACTION\b/i
      end

      def start_tracked_transaction(key, state, current_time, details)
        if state
          state["depth"] += 1
          state["last_seen_at"] = current_time
        elsif @transactions.length < details[:max_connections]
          @transactions[key] = {"started_at" => current_time, "last_seen_at" => current_time, "depth" => 1}
        end
      end

      def finish_tracked_transaction(data, key, state, current_time)
        @transactions.delete(key)
        elapsed = [(current_time - state["started_at"]) * 1000.0, 0.0].max
        data["transaction_duration_ms"] = elapsed.round(3)
      end

      def expire_tracked_transactions(current_time, ttl)
        @transactions.delete_if { |_key, state| current_time - state["last_seen_at"] > ttl }
      end

      def monotonic_now
        @clock.call.to_f
      rescue StandardError
        Time.now.to_f
      end

      def default_query_inspector
        defined?(ActiveRecordQueryInspector) ? ActiveRecordQueryInspector.new : nil
      rescue StandardError
        nil
      end

      def query_inspection_suppressed?
        defined?(ActiveRecordQueryInspector) && ActiveRecordQueryInspector.suppressed?
      rescue StandardError
        false
      end

      def safe_error_class(error)
        error.class.name.to_s[0, 128]
      rescue StandardError
        "StandardError"
      end

      def mailer(payload, duration)
        data = {
          "kind" => "mailer", "mailer" => value(payload, :mailer).to_s,
          "action" => value(payload, :action).to_s, "duration_ms" => duration
        }
        @notifier.record_event("job", data)
      end

      def active_job(payload, duration)
        job = value(payload, :job)
        exception = job_exception(payload)
        data = {
          "kind" => "active_job", "class" => safe_class_name(job),
          "adapter" => active_job_adapter(job), "job_id" => safe_job_value(job, :job_id),
          "provider_job_id" => safe_job_value(job, :provider_job_id),
          "queue" => safe_job_value(job, :queue_name), "attempts" => job_attempts(job),
          "duration_ms" => duration, "status" => exception ? "failed" : "completed"
        }
        data["error_class"] = exception.class.name.to_s if exception
        @notifier.record_event("job", data)
        @notifier.notify_once(exception, :context => {"job" => data}) if exception
      end

      def job_exception(payload)
        exception = value(payload, :exception_object)
        details = value(payload, :exception)
        exception ||= RuntimeError.new(Array(details).last.to_s) if details
        exception
      end

      def active_job_adapter(job)
        adapter = job.respond_to?(:queue_adapter) ? job.queue_adapter : nil
        adapter = adapter.class if adapter && !adapter.is_a?(Class)
        adapter ? adapter.name.to_s.split("::").last.to_s.sub(/Adapter$/, "") : ""
      rescue StandardError
        ""
      end

      def job_attempts(job)
        value = job.respond_to?(:executions) ? job.executions : 0
        value.is_a?(Numeric) ? value.to_i : 0
      rescue StandardError
        0
      end

      def cache(name, payload, duration)
        data = @cache_normalizer.call(name, payload).merge("duration_ms" => duration)
        @notifier.record_event("cache", data)
      end

      def capture_controller_exception(payload)
        exception = value(payload, :exception_object)
        details = value(payload, :exception)
        exception ||= RuntimeError.new(Array(details).last.to_s) if details
        @notifier.notify_once(exception, :parameters => hash(value(payload, :params))) if exception
      end

      def value(payload, key)
        payload.key?(key) ? payload[key] : payload[key.to_s]
      end

      def hash(value)
        value.is_a?(Hash) ? value : {}
      end

      def duration_ms(started_at, finished_at)
        return 0.0 unless started_at && finished_at

        ((finished_at.to_f - started_at.to_f) * 1000.0).round(3)
      end

      def query_free_path(path)
        path.to_s.split("?", 2).first
      end

      def route(payload)
        explicit = value(payload, :route)
        return explicit.to_s unless explicit.to_s.empty?

        [value(payload, :controller), value(payload, :action)].compact.join("#")
      end

      def safe_basename(identifier)
        File.basename(identifier.to_s)
      rescue StandardError
        "<template>"
      end

      def safe_class_name(object)
        object ? object.class.name.to_s : ""
      rescue StandardError
        "Object"
      end

      def safe_job_value(job, method_name)
        job.respond_to?(method_name) ? job.public_send(method_name).to_s : ""
      rescue StandardError
        ""
      end

      def record_once(key, event_type, payload)
        if @notifier.respond_to?(:record_event_once)
          @notifier.record_event_once(key, event_type, payload)
        else
          @notifier.record_event(event_type, payload)
        end
      end

      def slow_query_threshold
        options = @notifier.respond_to?(:apm_integration_options) ? @notifier.apm_integration_options : {}
        (options[:slow_query_threshold_ms] || 500.0).to_f
      rescue StandardError
        500.0
      end

      def sampled_query_source
        options = @notifier.respond_to?(:apm_integration_options) ? @notifier.apm_integration_options : {}
        root = options[:root_directory].to_s
        frame = caller.find do |line|
          (root.empty? || line.start_with?(root)) && line !~ %r{/lib/chronos/}
        end
        frame.to_s.sub(/:in .*/, "")[0, 256]
      rescue StandardError
        ""
      end
    end
  end
end
