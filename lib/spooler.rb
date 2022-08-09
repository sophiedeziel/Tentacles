# frozen_string_literal: true

require File.expand_path('../config/environment', __dir__)

Rails.application.reloader.wrap do
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
        pass
      end
    end

    private

    def log(message)
      puts "#{" " * (15 - "Spooler".size) } [ #{Spooler} ] : #{message}"
    end

    def subcribe_to_commands
      begin
        Redis.current.subscribe('printers') do |on|
          on.message do |channel, message|
            message = JSON.parse(message).deep_symbolize_keys
            printer = Printer.find(message[:printer_id])

            case message[:command]
            when 'add_printer'
              if @workers[message[:printer_id]].nil?
                @workers[printer.id] = Spool.new(printer)
                log "Added a new printer: #{printer.name}"
              end
            when 'start_print'
              log "Enqueuing on #{printer.name} : File id #{message[:file_id]}"
              @workers[printer.id].enqueue(Print, message[:file_id])
            when 'stop_print'
              log "Stopping print on #{printer.name}"
              @workers[printer.id].stop
            when 'resume'
              log "Resuming work on #{printer.name}"
              @workers[printer.id].resume
            end
          end
        end
      rescue StandardError => e
        puts e.message.red
      end
    end
  end

  Spooler.new.run
end
