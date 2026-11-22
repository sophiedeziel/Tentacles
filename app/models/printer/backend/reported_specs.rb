# typed: strict
# frozen_string_literal: true

class Printer
  class Backend
    # What a printer's server reports about the printer (see Printer::Backend#reported_specs): its name, and the
    # Printer::Specs columns of the same names. nil when the server doesn't report it. No server reports a brand,
    # temperatures or materials yet: they are here so that Types::PrinterSpecs resolves a ReportedSpecs like a Printer.
    #
    #   specs = Printer::Backend::ReportedSpecs.new(name: 'Prusa MK4', firmware: 'prusa_firmware', extruders: '1')
    #   specs.extruders          # => 1
    #   specs.attributes.compact # => { "name" => "Prusa MK4", "firmware" => "prusa_firmware", "extruders" => 1 }
    #   specs.save               # raises ApplicationModel::ReadOnlyRecord: it's the server's, Tentacles can't change it
    class ReportedSpecs < ApplicationModel
      attribute :name, :string
      attribute :brand, :string
      attribute :model, :string
      attribute :firmware, :string
      attribute :firmware_version, :string
      # In mm: X, Y and Z for a rectangular bed, the diameter and Z for a circular bed
      attribute :bed_shape, :string
      attribute :build_volume_x, :float
      attribute :build_volume_y, :float
      attribute :build_volume_z, :float
      attribute :build_diameter, :float
      attribute :extruders, :integer
      attribute :nozzle_diameter, :float
      attribute :max_hotend_temp, :integer
      attribute :max_bed_temp, :integer
      attribute :heated_bed, :boolean
      attribute :heated_chamber, :boolean
      attribute :webcam, :boolean
      # nil (not []) when not reported, like the other attributes
      attribute :materials, ArrayType.new(:string)

      sig { override.returns(T::Boolean) }
      def readonly?
        true
      end
    end
  end
end
