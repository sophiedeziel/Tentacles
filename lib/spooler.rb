# frozen_string_literal: true

require File.expand_path('../config/environment', __dir__)

require_relative 'spooler/spool'
require_relative 'spooler/operation'
# require 'rainbow/refinement'
class Spooler
  WAIT_TIME = 0.5.seconds

  def initialize
    @workers = {}
    Printer.all.each do |printer|
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

  # rubocop:disable Metrics/MethodLength
  def subcribe_to_commands
    REDIS_POOL.with do |conn|
      conn.subscribe('printers') do |on|
        on.message do |_channel, message|
          message = JSON.parse(message).deep_symbolize_keys
          printer = Printer.find(message[:printer_id])
          command = message.delete(:command)

          send_command(printer, command, message)
        end
      end
    end
  rescue StandardError => e
    log e.message.red
  end
  # rubocop:enable Metrics/MethodLength

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
