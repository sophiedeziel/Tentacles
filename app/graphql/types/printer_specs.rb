# typed: true
# frozen_string_literal: true

module Types
  # Resolves anything with the readers of the Printer::Specs columns (brand, firmware, bed_shape, build_volume_x, ...):
  # a ::Printer for its saved specs, a PrinterBackends::ReportedSpecs for what its server reports.
  class PrinterSpecs < Base::Object
    extend T::Sig

    description 'What a printer is and can do, shown in "About This Printer". Null when not set.'
    default_broadcastable true

    field :brand, String, null: true
    field :model, String, null: true
    field :firmware, Types::PrinterFirmware, null: true, description: 'OTHER for a firmware Tentacles does not know'
    field :firmware_display_name, String, null: true, description: 'The firmware as saved, e.g. "klipper" or "Smoothie"'
    field :firmware_version, String, null: true
    field :build_volume, Types::BuildVolume, null: true,
                                             description: 'Rectangular or circular, by bed shape (rectangular when ' \
                                                          'not set). Null until every dimension of that shape is set.'
    field :extruders, Integer, null: true
    field :nozzle_diameter, Float, null: true, description: 'In mm'
    field :max_hotend_temp, Integer, null: true, description: 'In °C'
    field :max_bed_temp, Integer, null: true, description: 'In °C'
    field :heated_bed, Boolean, null: true
    field :heated_chamber, Boolean, null: true
    field :webcam, Boolean, null: true
    field :materials, [String], null: false, description: 'Materials it prints, e.g. ["PLA", "PETG"]'

    sig { returns(T.nilable(String)) }
    def firmware
      firmware = object.firmware
      return if firmware.nil?

      ::Printer::Specs::KNOWN_FIRMWARES.include?(firmware) ? firmware : 'other'
    end

    sig { returns(T.nilable(String)) }
    def firmware_display_name
      object.firmware
    end

    # The Hash BuildVolume resolves its type from: { x:, y:, z: }, or { diameter:, height: } for a circular bed
    sig { returns(T.nilable(T::Hash[Symbol, Float])) }
    def build_volume
      if object.bed_shape == 'circular'
        dimensions(diameter: object.build_diameter, height: object.build_volume_z)
      else
        dimensions(x: object.build_volume_x, y: object.build_volume_y, z: object.build_volume_z)
      end
    end

    # Printers saved before the column existed have nil
    sig { returns(T::Array[String]) }
    def materials
      object.materials || []
    end

    private

    sig { params(sizes: T.nilable(Numeric)).returns(T.nilable(T::Hash[Symbol, Float])) }
    def dimensions(**sizes)
      sizes.transform_values(&:to_f) if sizes.values.none?(&:nil?)
    end
  end
end
