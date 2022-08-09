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
        @workers[printer.id] = Spool.new(printer.name)
      end
    end

    def run
      @workers[8].start(Print.new(Printer.all.first, FileManager::File.find(3)))

      loop do
        sleep(WAIT_TIME)
      end
    end

  end


  Spooler.new.run
end
