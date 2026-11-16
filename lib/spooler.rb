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

  # One command published on the `printers` channel. Its errors are logged, so a bad message (e.g. for a printer
  # removed since) never ends the subscription.
  def handle_message(message)
    message = JSON.parse(message).deep_symbolize_keys
    command = message.delete(:command)
    # The printer is already deleted: it can't be read
    return remove_printer(message[:printer_id]) if command == 'remove_printer'

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

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def send_command(printer, command, opts)
    case command
    when 'add_printer'
      if @workers[opts[:printer_id]].nil?
        @workers[printer.id] = Spool.new(printer)
        log "Added a new printer: #{printer.name}"
      end
    when 'start_print'
      unless @workers[printer.id].working?
        log "Starting job on #{printer.name}"
        @workers[printer.id].resume
      end
    when 'stop_print'
      log "Stopping print on #{printer.name}"
      @workers[printer.id].stop
    when 'resume'
      log "Resuming work on #{printer.name}"
      @workers[printer.id].resume
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
end
