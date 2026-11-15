# typed: true
# frozen_string_literal: true

module PrinterMonitor
  # Runs one Worker per printer and keeps the workers in sync with the printers table.
  #
  # The printer list is re-read every 30 seconds: workers are started for new printers, stopped for removed ones
  # (their snapshots are deleted) and restarted when a printer's backend or credentials changed.
  #
  # The supervisor also writes the monitor's heartbeat every 5 seconds, so that the monitor looks healthy when there
  # are no printers, or when every printer is unreachable and their workers back off for longer than that.
  #
  #   PrinterMonitor::Supervisor.new.run # Blocks until INT or TERM
  class Supervisor
    extend T::Sig

    REFRESH_INTERVAL = 30.0
    # Must stay well below PrinterStatusStore::HEALTHY_WITHIN
    HEARTBEAT_INTERVAL = 5.0
    # Seconds to wait for a worker to finish its tick when stopping it
    JOIN_TIMEOUT = 10
    SIGNALS = %w[INT TERM].freeze

    WorkerFactory = T.type_alias { T.proc.params(printer: Printer).returns(Worker) }

    sig { params(worker_factory: T.nilable(WorkerFactory), refresh_interval: Float, heartbeat_interval: Float).void }
    def initialize(worker_factory: nil, refresh_interval: REFRESH_INTERVAL, heartbeat_interval: HEARTBEAT_INTERVAL)
      @worker_factory = T.let(worker_factory || ->(printer) { Worker.new(printer) }, WorkerFactory)
      @refresh_interval = refresh_interval
      @heartbeat_interval = heartbeat_interval
      @steps = T.let(0, Integer)
      @heartbeat = T.let(Heartbeat.new, Heartbeat)
      @workers = T.let({}, T::Hash[Integer, Worker])
      # The credentials each worker was started with (see Printer#api_credentials)
      @credentials = T.let({}, T::Hash[Integer, T::Array[T.nilable(String)]])
      @stop_signal = T.let(Thread::Queue.new, Thread::Queue)
    end

    sig { returns(T::Hash[Integer, Worker]) }
    def workers
      @workers.dup
    end

    # Monitors the printers until INT or TERM is received (or #stop is called), then stops the workers
    sig { void }
    def run
      trap_signals
      log('Starting')
      loop do
        step
        break if @stop_signal.pop(timeout: @heartbeat_interval)
      end
      shutdown
    end

    # One step of the run loop (every 5 seconds): refreshes the printers every 30 seconds and writes the heartbeat
    sig { void }
    def step
      refresh if refresh_due?
      @steps += 1
      @heartbeat.beat
    end

    # Safe to call from a signal handler
    sig { void }
    def stop
      @stop_signal << :stop
    end

    # Starts, stops and restarts workers to match the printers table
    sig { void }
    def refresh
      printers = Rails.application.executor.wrap { Printer.all.to_a }
      removed_ids = @workers.keys - printers.map(&:id)
      remove_workers(removed_ids) if removed_ids.any?
      printers.each { |printer| sync_worker(printer) }
    rescue StandardError => e
      log("Failed to refresh the printers: #{e.class}: #{e.message}", level: :error)
    end

    sig { void }
    def shutdown
      log('Stopping')
      stop_workers(@workers.keys)
      log('Stopped')
    end

    private

    # Steps are counted rather than timed, so that a clock change can't delay the refresh
    sig { returns(T::Boolean) }
    def refresh_due?
      refresh_every = [(@refresh_interval / @heartbeat_interval).round, 1].max
      (@steps % refresh_every).zero?
    end

    # The trap handler runs on the main thread, which is waiting in Queue#pop: a push from the handler itself
    # would only be noticed when the wait times out, so it is pushed from another thread.
    sig { void }
    def trap_signals
      SIGNALS.each { |signal| Signal.trap(signal) { Thread.new { stop } } }
    end

    sig { params(printer: Printer).void }
    def sync_worker(printer)
      credentials = printer.api_credentials
      return if @workers.key?(printer.id) && @credentials[printer.id] == credentials

      if @workers.key?(printer.id)
        log("Restarting the worker of #{printer.name} (##{printer.id}), its credentials changed")
        stop_workers([printer.id])
      end
      start_worker(printer, credentials)
    end

    sig { params(printer: Printer, credentials: T::Array[T.nilable(String)]).void }
    def start_worker(printer, credentials)
      @workers[printer.id] = @worker_factory.call(printer).start
      @credentials[printer.id] = credentials
      log("Monitoring #{printer.name} (##{printer.id})")
    end

    sig { params(printer_ids: T::Array[Integer]).void }
    def remove_workers(printer_ids)
      stop_workers(printer_ids)
      # Deleted after the workers stopped, so that a tick in progress can't write the snapshot back
      PrinterStatusStore.delete(printer_ids)
      log("Stopped monitoring removed printers #{printer_ids.join(', ')}")
    end

    # Stops the workers first and joins them after, so that they stop in parallel
    sig { params(printer_ids: T::Array[Integer]).void }
    def stop_workers(printer_ids)
      stopping = printer_ids.filter_map { |id| @workers.delete(id) }
      @credentials.reject! { |id, _credentials| printer_ids.include?(id) }
      stopping.each(&:stop)
      stopping.each { |worker| worker.join(JOIN_TIMEOUT) }
    end

    sig { params(message: String, level: Symbol).void }
    def log(message, level: :info)
      Rails.logger.public_send(level, "[PrinterMonitor] #{message}")
    end
  end
end
