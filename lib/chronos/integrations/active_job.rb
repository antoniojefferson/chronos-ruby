require "securerandom"

module Chronos
  module Integrations
    # Propagates bounded Chronos context through Active Job serialization.
    #
    # @responsibility Add trace/request identifiers to the job envelope and restore them while performing.
    # @motivation Active Job adapters commonly cross process boundaries where thread-local context is lost.
    # @limits It changes only a namespaced serialization field, never public job arguments or adapter behavior.
    # @collaborators ActiveJob::Base serialization hooks and the Chronos facade.
    # @thread_safety Installation is mutex-protected and each job owns its restored context.
    # @compatibility Active Job shipped with Rails 4.2 through Rails 5.2.
    # @example
    #   Chronos::Integrations::ActiveJob.install(ActiveJob::Base)
    # @errors Context failures are contained so enqueue and perform semantics remain unchanged.
    # @performance Adds at most two strings of 128 bytes to a serialized job.
    module ActiveJob
      CONTEXT_KEY = "chronos_context".freeze
      SCHEMA_VERSION = "1.0".freeze
      MAX_IDENTIFIER_BYTES = 128

      @mutex = Mutex.new

      class << self
        def install(base = nil, notifier = Chronos)
          target = base || (::ActiveJob::Base if defined?(::ActiveJob::Base))
          return false unless target && target.respond_to?(:prepend)

          @mutex.synchronize do
            return false if target.ancestors.include?(JobExtensions)

            JobExtensions.notifier = notifier
            target.send(:prepend, JobExtensions)
          end
          true
        rescue StandardError
          false
        end

        def envelope(notifier)
          source = notifier.respond_to?(:propagation_context) ? notifier.propagation_context : {}
          source = {} unless source.is_a?(Hash)
          context = %w(trace_id request_id).each_with_object({}) do |key, result|
            value = source[key] || source[key.to_sym]
            result[key] = bounded(value) unless value.to_s.empty?
          end
          context["trace_id"] = SecureRandom.uuid if context["trace_id"].to_s.empty?
          {"schema_version" => SCHEMA_VERSION, "context" => context}
        rescue StandardError
          nil
        end

        def context(value)
          return {} unless value.is_a?(Hash)
          return {} unless (value["schema_version"] || value[:schema_version]).to_s == SCHEMA_VERSION

          source = value["context"] || value[:context]
          return {} unless source.is_a?(Hash)

          %w(trace_id request_id).each_with_object({}) do |key, result|
            candidate = source[key] || source[key.to_sym]
            result[key] = bounded(candidate) unless candidate.to_s.empty?
          end
        rescue StandardError
          {}
        end

        private

        def bounded(value)
          string = value.to_s
          return string if string.bytesize <= MAX_IDENTIFIER_BYTES

          string.byteslice(0, MAX_IDENTIFIER_BYTES)
        rescue StandardError
          ""
        end
      end

      # Active Job instance hooks installed through Module#prepend.
      module JobExtensions
        class << self
          attr_accessor :notifier
        end

        def serialize(*arguments)
          data = super
          begin
            envelope = Chronos::Integrations::ActiveJob.envelope(JobExtensions.notifier || Chronos)
            data[CONTEXT_KEY] = envelope if data.is_a?(Hash) && envelope
          rescue StandardError
            nil
          end
          data
        end

        def deserialize(job_data)
          result = super
          begin
            @chronos_context = Chronos::Integrations::ActiveJob.context(
              job_data.is_a?(Hash) ? (job_data[CONTEXT_KEY] || job_data[CONTEXT_KEY.to_sym]) : nil
            )
          rescue StandardError
            @chronos_context = {}
          end
          result
        end

        def perform_now(*arguments, &block)
          context = @chronos_context || {}
          notifier = JobExtensions.notifier || Chronos
          return super if context.empty? || !notifier.respond_to?(:with_context)

          notifier.with_context(:context => context) { super }
        end
      end
    end
  end
end
