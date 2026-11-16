# typed: strict
# frozen_string_literal: true

module PrinterBackends
  # What a printer's server reports about the printer (see Base#reported_specs): its name, and the Printer::Specs
  # columns of the same names. nil when the server doesn't report it. No server reports a brand, temperatures or
  # materials yet: they are here so that Types::PrinterSpecs resolves a ReportedSpecs like a Printer.
  #
  #   PrinterBackends::ReportedSpecs.new(name: 'Prusa MK4', firmware: 'prusa_firmware', nozzle_diameter: 0.4)
  class ReportedSpecs < T::Struct
    const :name, T.nilable(String)
    const :brand, T.nilable(String)
    const :model, T.nilable(String)
    const :firmware, T.nilable(String)
    const :firmware_version, T.nilable(String)
    # In mm: X, Y and Z for a rectangular bed, the diameter and Z for a circular bed
    const :bed_shape, T.nilable(String)
    const :build_volume_x, T.nilable(Float)
    const :build_volume_y, T.nilable(Float)
    const :build_volume_z, T.nilable(Float)
    const :build_diameter, T.nilable(Float)
    const :extruders, T.nilable(Integer)
    const :nozzle_diameter, T.nilable(Float)
    const :max_hotend_temp, T.nilable(Integer)
    const :max_bed_temp, T.nilable(Integer)
    const :heated_bed, T.nilable(T::Boolean)
    const :heated_chamber, T.nilable(T::Boolean)
    const :webcam, T.nilable(T::Boolean)
    const :materials, T.nilable(T::Array[String])
  end
end
