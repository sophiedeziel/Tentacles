# typed: true
# frozen_string_literal: true

require File.expand_path('../config/environment', __dir__)

require_relative 'spooler/spool'
require_relative 'spooler/operation'
# require 'rainbow/refinement'
class Spooler
  WAIT_TIME = 0.5.seconds

  def initialize
    @workers = {}
    Printer.find_each do |printer|
      @workers[printer.id] = Spool.new(printer)
    end
  end

  # Starts the sweep, then listens to the commands. Redis#subscribe blocks for the life of the process: the spools and
  # the sweep run in their own threads beside it.
  def run
    start_sweep
    subcribe_to_commands
  end

  def log(message)
    puts "#{' ' * (15 - 'Spooler'.size)} [ Spooler ] : #{message}"
  end

  def subcribe_to_commands
    REDIS_POOL.with do |conn|
      conn.subscribe('printers') do |on|
        on.message { |_channel, message| handle_message(message) }
      end
    end
  end

  # One command published on the `printers` channel (see Printer::SpoolerCommand). Its errors are logged, so a bad
  # message (an unknown command, a printer removed since, ...) never ends the subscription.
  def handle_message(message)
    message = JSON.parse(message).deep_symbolize_keys
    command = Printer::SpoolerCommand.deserialize(message.delete(:command))
    # The printer is already deleted: it can't be read
    return remove_printer(message[:printer_id]) if command == Printer::SpoolerCommand::RemovePrinter
    # For the whole queue, not a printer
    return dispatch if command == Printer::SpoolerCommand::Dispatch

    printer = Printer.find(message[:printer_id])
    send_command(printer, command, message)
  rescue StandardError => e
    log e.message.red
  end

  # A dispatch pass of the global queue (PrintQueue::Dispatch). The copies it creates are started by the start_print
  # messages it publishes, handled after this one. Its errors are logged: the sweep runs the next pass.
  def dispatch
    Rails.application.executor.wrap { PrintQueue::Dispatch.new.save! }
  rescue StandardError => e
    log "Dispatch failed: #{e.class}: #{e.message}".red
  end

  # Sweeps now, then every PrintQueue::SWEEP_INTERVAL, in a thread of its own (see #sweep)
  def start_sweep
    @sweep_thread = Thread.new do
      loop do
        sweep
        sleep(PrintQueue::SWEEP_INTERVAL.to_f)
      end
    end
  end

  # While the global queue is on: a dispatch pass, then the idle spools of the printers with an enqueued copy are
  # resumed (PrintQueue::Sweep). A start_print ignored while the spool still looked busy, or lost, can't leave a copy
  # enqueued for good, and the copies left enqueued by a restart are started. Its errors are logged and the next sweep
  # runs.
  def sweep
    return unless PrintQueue.enabled?

    printer_ids = Rails.application.executor.wrap { PrintQueue::Sweep.new.tap(&:save!).printer_ids }
    resume_idle_spools(printer_ids)
  rescue StandardError => e
    log "Sweep failed: #{e.class}: #{e.message}".red
  end

  # Resumes the spools of these printers that aren't working: each takes its printer's next job
  def resume_idle_spools(printer_ids)
    printer_ids.each do |printer_id|
      spool = @workers[printer_id]
      next if spool.nil? || spool.working?

      log "Sweep: resuming the spool of printer #{printer_id}"
      spool.resume
    end
  end

  # Drops the spool of a removed printer, without sending anything to the printer: a print under way keeps running
  def remove_printer(printer_id)
    spool = @workers.delete(printer_id)
    return if spool.nil?

    spool.discard
    log "Removed printer #{printer_id}"
  end

  # The commands for a printer that still exists: remove_printer and dispatch are handled by #handle_message, before
  # the lookup.
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  #: (
  #|   Printer printer,
  #|   (Printer::SpoolerCommand::AddPrinter | Printer::SpoolerCommand::StartPrint |
  #|    Printer::SpoolerCommand::StopPrint | Printer::SpoolerCommand::Resume) command,
  #|   Hash[Symbol, untyped] opts
  #| ) -> void
  def send_command(printer, command, opts)
    case command
    when Printer::SpoolerCommand::AddPrinter
      if @workers[opts[:printer_id]].nil?
        @workers[printer.id] = Spool.new(printer)
        log "Added a new printer: #{printer.name}"
      end
    when Printer::SpoolerCommand::StartPrint
      unless @workers[printer.id].working?
        log "Starting job on #{printer.name}"
        @workers[printer.id].resume
      end
    when Printer::SpoolerCommand::StopPrint
      log "Stopping print on #{printer.name}"
      @workers[printer.id].stop
    when Printer::SpoolerCommand::Resume
      log "Resuming work on #{printer.name}"
      @workers[printer.id].resume
    else T.absurd(command)
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
end
