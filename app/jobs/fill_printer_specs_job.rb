# typed: true
# frozen_string_literal: true

# Fills the blank specs of one printer with what its server reports (Printer::Specs#fill_specs_from_server), which
# sets `specs_filled_at` when it read the server. Enqueued per printer by
# db/migrate/20261116100000_enqueue_fill_printer_specs.rb (printers added before autofill), and by the monitor when a
# printer whose server was never read answers (PrinterMonitor::Worker). Best effort: a printer whose server can't be
# read keeps its blank specs, logged; the monitor tries again after it restarts.
class FillPrinterSpecsJob < ApplicationJob
  extend T::Sig

  queue_as :default

  sig { params(printer_id: Integer).void }
  def perform(printer_id)
    # Removed since it was enqueued
    printer = Printer.find_by(id: printer_id)
    return unless printer

    filled = printer.fill_specs_from_server
    result = if filled.nil? then 'the server could not be read, nothing filled'
             elsif filled.empty? then 'nothing to fill'
             else "filled #{filled.join(', ')}"
             end
    Rails.logger.info("[FillPrinterSpecsJob] #{printer.name} (##{printer.id}): #{result}")
  end
end
