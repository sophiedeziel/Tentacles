# typed: strict
# frozen_string_literal: true

class Printer
  # Saves a new printer and gets it going, for addPrinter and for the OctoPrint approval (OctoprintAppKeyPollJob):
  #
  #   addition = Printer::Addition.new(name: 'Ender 3', backend: 'octoprint', uri: 'http://192.168.1.57/', secret: key)
  #   addition.save    # false when the printer is invalid: see addition.errors (the printer's own errors)
  #   addition.printer # the new printer
  #
  # Once saved, the spooler is told (so the printer gets a spool without a restart) and the blank specs are filled
  # from the printer's server. Both are best effort: the printer stays added when they fail.
  class Addition < ApplicationModel
    attribute :name, :string
    attribute :backend, :string
    attribute :uri, :string
    attribute :username, :string
    attribute :secret, :string

    validate :printer_must_be_valid

    after_save :start_spool, :fill_specs

    # The attributes left out get the printer's defaults (backend: 'octoprint')
    sig { returns(::Printer) }
    def printer
      @printer ||= T.let(::Printer.new(attributes.compact), T.nilable(::Printer))
    end

    # The merged errors are named like the printer's attributes (config/locales: "URL", "API key or password")
    sig { params(attribute: T.any(String, Symbol), options: T::Hash[Symbol, T.untyped]).returns(String) }
    def self.human_attribute_name(attribute, options = {})
      ::Printer.human_attribute_name(attribute, options)
    end

    private

    # Printer's validations, with its error messages ("URL can't be blank")
    sig { void }
    def printer_must_be_valid
      errors.merge!(printer.errors) unless printer.valid?
    end

    sig { void }
    def persist
      printer.save!
    end

    sig { void }
    def start_spool
      printer.notify_spooler(:add_printer)
    rescue Redis::BaseError, ConnectionPool::TimeoutError => e
      Rails.logger.error("[Printer::Addition] Could not publish add_printer for printer #{printer.id}: #{e.message}")
    end

    sig { void }
    def fill_specs
      printer.fill_specs_from_server
    end
  end
end
