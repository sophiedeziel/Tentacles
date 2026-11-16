# typed: strict
# frozen_string_literal: true

module Printers
  # Saves a new printer and gets it going, for addPrinter and for the OctoPrint approval (OctoprintAppKeyPollJob):
  #
  #   printer = Printers::Add.call(name: 'Ender 3', backend: 'octoprint', uri: 'http://192.168.1.57/', secret: key)
  #   printer.persisted? # false when it's invalid: see printer.errors
  #
  # Once saved, the spooler is told (so the printer gets a spool without a restart) and the blank specs are filled
  # from the printer's server. Both are best effort: the printer stays added when they fail.
  class Add
    extend T::Sig

    sig { params(attributes: T.untyped).returns(::Printer) }
    def self.call(**attributes)
      printer = ::Printer.new(attributes)
      return printer unless printer.save

      start_spool(printer)
      printer.fill_specs_from_server
      printer
    end

    sig { params(printer: ::Printer).void }
    def self.start_spool(printer)
      printer.notify_spooler(:add_printer)
    rescue Redis::BaseError, ConnectionPool::TimeoutError => e
      Rails.logger.error("[Printers::Add] Could not publish add_printer for printer #{printer.id}: #{e.message}")
    end
    private_class_method :start_spool
  end
end
