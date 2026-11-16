# frozen_string_literal: true

module InputObjects
  class PrinterSpecsInput < Base::InputObject
    description 'What a printer is and can do (see PrinterSpecs). Only the fields sent are written: an omitted ' \
                'field stays as it is, null clears it.'

    argument :brand, String, required: false
    argument :model, String, required: false
    argument :firmware, String, required: false,
                                description: 'Free text: "marlin", "klipper", "prusa_firmware" and "reprapfirmware" ' \
                                             'are known, anything else is OTHER'
    argument :firmware_version, String, required: false
    argument :build_volume, InputObjects::BuildVolumeInput, required: false,
                                                            description: 'Sets the bed shape with its dimensions. ' \
                                                                         'Null clears both.'
    argument :extruders, Integer, required: false
    argument :nozzle_diameter, Float, required: false, description: 'In mm'
    argument :max_hotend_temp, Integer, required: false, description: 'In °C'
    argument :max_bed_temp, Integer, required: false, description: 'In °C'
    argument :heated_bed, Boolean, required: false
    argument :heated_chamber, Boolean, required: false
    argument :webcam, Boolean, required: false
    argument :materials, [String], required: false, description: 'e.g. ["PLA", "PETG"], null clears them'

    # The Printer::Specs columns to write: only the fields that were sent
    def to_attributes
      attributes = to_h.except(:build_volume)
      return attributes unless key?(:build_volume)

      attributes.merge(build_volume ? build_volume.to_attributes : BuildVolumeInput.cleared_attributes)
    end
  end
end
