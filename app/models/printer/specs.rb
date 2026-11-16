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
    extend T::Sig
    extend ActiveSupport::Concern

    KNOWN_FIRMWARES = %w[marlin klipper prusa_firmware reprapfirmware].freeze
    BED_SHAPES = %w[rectangular circular].freeze

    included do
      T.bind(self, T.class_of(Printer))

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
  end
end
