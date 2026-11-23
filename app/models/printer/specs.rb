# typed: true
# frozen_string_literal: true

class Printer
  # What the "About This Printer" card shows: brand, model, firmware, build volume, capabilities and materials.
  #
  # Every column is nullable and nil means "never set" (autofill only fills nil columns), except `materials`, which is
  # [] when there are none. The build volume is in mm: X, Y and Z for a rectangular bed, or the diameter and Z for a
  # circular (delta) bed, whose X and Y stay nil. `firmware` is free text: GraphQL maps the KNOWN_FIRMWARES to their
  # PrinterFirmware value, and anything else to OTHER.
  module Specs
    extend ActiveSupport::Concern

    KNOWN_FIRMWARES = %w[marlin klipper prusa_firmware reprapfirmware].freeze
    BED_SHAPES = %w[rectangular circular].freeze

    included do
      #: self as singleton(Printer)

      attribute :materials, :json, default: -> { [] }

      normalizes :brand, :model, :firmware, :firmware_version, with: ->(value) { value.strip.presence }
      normalizes :materials, apply_to_nil: true,
                             with: ->(list) { Array(list).map { |material| material.to_s.strip }.compact_blank.uniq }

      # :firmware is free text, no inclusion check
      validates :bed_shape, inclusion: { in: BED_SHAPES }, allow_nil: true
      validates :build_volume_x, :build_volume_y, :build_volume_z, :build_diameter, :nozzle_diameter,
                numericality: { greater_than: 0 }, allow_nil: true
      validates :extruders, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
      validates :max_hotend_temp, :max_bed_temp, numericality: { only_integer: true, in: 0..500 }, allow_nil: true
    end

    # Why a printer's server can't be read: the adapters' errors, and the answers of a server of another kind
    READ_ERRORS = [Printer::Backend::Error, JSON::ParserError, KeyError, URI::InvalidURIError].freeze

    # What the printer's server reports about it (Printer::Backend#reported_specs), cached for 2 hours. nil when it
    # can't be reached; other errors are raised (see Printer#using_api).
    #: -> Printer::Backend::ReportedSpecs?
    def reported_specs
      # Cached as JSON: the reported attributes (the nil ones left out), not the model
      reported = T.bind(self, Printer).using_api(cache: 2.hours) do
        api.reported_specs.attributes.compact
      end
      return nil unless reported

      specs = Printer::Backend::ReportedSpecs
      specs.new(reported.stringify_keys.slice(*specs.attribute_names)) # A cached attribute may have been removed since
    end

    # Copies each reported value into a column that is still nil, then saves: never overwrites a value (false
    # included). A value the columns refuse (e.g. a 0 mm nozzle) stays nil. Returns the columns filled.
    #: (Printer::Backend::ReportedSpecs reported) -> Array[String]
    def fill_blank_specs(reported)
      # The name is the user's: it is never blank
      #: self as Printer
      values = reported.attributes.compact.except('name').select { |column, _| self[column].nil? }
      assign_attributes(values)
      filled = values.keys - refused_specs(values.keys)
      return filled if save

      restore_attributes(values.keys)
      []
    end

    # Fills the blank specs with what the printer's server reports (#reported_specs, cached 2 hours), when a printer
    # is added or its address changes, and by FillPrinterSpecsJob. Saves when it read the server in `specs_filled_at`
    # (the monitor fills the printers where it is nil). Best effort: nil, logged, when the server can't be read.
    #: -> Array[String]?
    def fill_specs_from_server
      reported = reported_specs
      return nil unless reported

      filled = fill_blank_specs(reported)
      # Even when nothing was filled, or the save failed: the server was read
      T.bind(self, Printer).update_column(:specs_filled_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
      filled
    rescue *READ_ERRORS, Redis::BaseError, ConnectionPool::TimeoutError => e
      Rails.logger.error("Could not read the specs of printer #{T.bind(self, Printer).id}: #{e.class}: #{e.message}")
      nil
    end

    private

    # Puts back nil the columns that refuse their new value, and returns them
    #: (Array[String] columns) -> Array[String]
    def refused_specs(columns)
      #: self as Printer
      return [] if valid?

      refused = columns & errors.attribute_names.map(&:to_s)
      restore_attributes(refused)
      refused
    end
  end
end
