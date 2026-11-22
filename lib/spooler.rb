# typed: true
# frozen_string_literal: true

require File.expand_path('../config/environment', __dir__)

require_relative 'spooler/spool'
require_relative 'spooler/operation'
# require 'rainbow/refinement'
class Spooler
  extend T::Sig

  WAIT_TIME = 0.5.seconds

  def initialize
    @workers = {}
    Printer.find_each do |printer|
      @workers[printer.id] = Spool.new(printer)
    end
  end

  def run
    subcribe_to_commands

    loop do
      Thread.pass
    end
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

    printer = Printer.find(message[:printer_id])
    send_command(printer, command, message)
  rescue StandardError => e
    log e.message.red
  end

  # Drops the spool of a removed printer, without sending anything to the printer: a print under way keeps running
  def remove_printer(printer_id)
    spool = @workers.delete(printer_id)
    return if spool.nil?

    spool.discard
    log "Removed printer #{printer_id}"
  end

  # The commands for a printer that still exists: remove_printer is handled by #handle_message, before the lookup.
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  sig do
    params(
      printer: Printer,
      command: T.any(Printer::SpoolerCommand::AddPrinter, Printer::SpoolerCommand::StartPrint,
                     Printer::SpoolerCommand::StopPrint, Printer::SpoolerCommand::Resume),
      opts: T::Hash[Symbol, T.untyped]
    ).void
  end
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
