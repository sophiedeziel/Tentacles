# frozen_string_literal: true

namespace :printers do
  desc 'Fills the blank specs of every printer with what its server reports (once, for the printers added before ' \
       'autofill)'
  task fill_specs: :environment do
    Printer.find_each do |printer|
      filled = printer.fill_specs_from_server
      result = if filled.nil? then 'server could not be read, nothing filled'
               elsif filled.empty? then 'nothing to fill'
               else "filled #{filled.join(', ')}"
               end
      puts "#{printer.name} (##{printer.id}): #{result}"
    end
  end
end
