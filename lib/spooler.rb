# frozen_string_literal: true

require_relative 'spooler/queue'
require_relative 'spooler/operation'
require 'pry'
require 'rainbow/refinement'
require 'octoprint'
require 'colorize'

PRINTERS = [{ id: 8,
              name: 'Ender 3',
              octoprint_uri: 'http://10.0.1.165/',
              octoprint_key: 'A8DDB1359AAB415AB38C345129815DF4',
              created_at: '2022-05-06T01:54:42.191Z',
              updated_at: '2022-05-06T01:54:42.191Z' },
            { id: 9,
              name: 'Creality CR-10s',
              octoprint_uri: 'http://10.0.1.73/',
              octoprint_key: '5B64F2F9AEE5414FA55DE7F0BE6C42B1',
              created_at: '2022-05-06T01:55:06.022Z',
              updated_at: '2022-05-06T01:55:06.022Z' }].freeze

FILE = {
  name: 'home.gcode',
  path: './spec/fixture_files/home.gcode'
}

module Spooler

  workers = PRINTERS.map do |printer|
    queue = Queue.new(printer[:name])
    queue.start(Print.new(printer, FILE))
    queue
  end

  workers.first.start(Print.new(PRINTERS.first, FILE))

  loop do
  end
end
