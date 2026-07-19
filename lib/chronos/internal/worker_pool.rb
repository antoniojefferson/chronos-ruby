module Chronos
  module Internal
    # Fixed-size, lazy worker pool that drains a BoundedQueue.
    #
    # @responsibility Start workers on first use, deliver events, flush, and shut down predictably.
    # @motivation Keep serialization and network delivery outside the caller's critical path.
    # @limits Version 0.1 does not retry failed deliveries or persist a backlog.
    # @collaborators BoundedQueue, Transport, and SafeLogger.
    # @thread_safety Internal state is synchronized and active delivery is counted.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; workers are recreated after fork.
    # @example
    #   pool.enqueue(event)
    #   pool.flush(2.0)
    # @errors Worker errors are diagnosed and contained inside the pool.
    # @performance Creates a fixed number of threads only after the first accepted event.
    class WorkerPool
      POLL_INTERVAL = 0.05

      def initialize(queue, transport, worker_count, logger = nil)
        @queue = queue
        @transport = transport
        @worker_count = worker_count
        @logger = logger || SafeLogger.new(nil)
        @mutex = Mutex.new
        @threads = []
        @active = 0
        @closed = false
        @pid = Process.pid
      end

      def enqueue(event)
        prepare_after_fork
        return false if closed?

        accepted = @queue.push(event)
        ensure_started if accepted
        accepted
      end

      def flush(timeout)
        prepare_after_fork
        ensure_started unless @queue.empty?
        deadline = monotonic_time + timeout.to_f
        loop do
          return true if @queue.empty? && active_count.zero?
          return false if monotonic_time >= deadline
          sleep(POLL_INTERVAL)
        end
      end

      def close(timeout)
        already_closed = @mutex.synchronize do
          was_closed = @closed
          @closed = true
          was_closed
        end
        return true if already_closed

        flushed = flush_without_reopening(timeout)
        @queue.close
        join_workers(timeout)
        @transport.close
        flushed
      rescue StandardError => error
        @logger.warn("Chronos worker shutdown failed: #{error.class}")
        false
      end

      def started?
        @mutex.synchronize { !@threads.empty? }
      end

      private

      def ensure_started
        @mutex.synchronize do
          return if @closed || !@threads.empty?
          @worker_count.times { @threads << Thread.new { work_loop } }
        end
      end

      def work_loop
        loop do
          event = @queue.pop(POLL_INTERVAL)
          break if event.nil? && @queue.closed?
          next unless event

          increment_active
          begin
            @transport.send_event(event)
          rescue StandardError => error
            @logger.warn("Chronos worker contained #{error.class}")
          ensure
            decrement_active
          end
        end
      rescue StandardError => error
        @logger.warn("Chronos worker stopped after #{error.class}")
      end

      def prepare_after_fork
        return if @pid == Process.pid

        @mutex.synchronize do
          @pid = Process.pid
          @threads = []
          @active = 0
        end
      end

      def flush_without_reopening(timeout)
        deadline = monotonic_time + timeout.to_f
        loop do
          return true if @queue.empty? && active_count.zero?
          return false if monotonic_time >= deadline
          sleep(POLL_INTERVAL)
        end
      end

      def join_workers(timeout)
        deadline = monotonic_time + timeout.to_f
        threads = @mutex.synchronize { @threads.dup }
        threads.each do |thread|
          remaining = deadline - monotonic_time
          thread.join(remaining) if remaining > 0
          thread.kill if thread.alive?
        end
      end

      def increment_active
        @mutex.synchronize { @active += 1 }
      end

      def decrement_active
        @mutex.synchronize { @active -= 1 }
      end

      def active_count
        @mutex.synchronize { @active }
      end

      def closed?
        @mutex.synchronize { @closed }
      end

      def monotonic_time
        if Process.respond_to?(:clock_gettime) && defined?(Process::CLOCK_MONOTONIC)
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        else
          Time.now.to_f
        end
      end
    end
  end
end
