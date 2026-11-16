# frozen_string_literal: true

module Types
  class PrinterFirmware < Base::Enum
    description "The firmware a printer runs. `printers.firmware` is free text: the values Tentacles doesn't know " \
                'are OTHER, and PrinterSpecs.firmwareDisplayName has the saved text.'

    value 'MARLIN', 'Marlin', value: 'marlin'
    value 'KLIPPER', 'Klipper', value: 'klipper'
    value 'PRUSA_FIRMWARE', 'Prusa Firmware (Prusa MK4, XL, MINI, ...)', value: 'prusa_firmware'
    value 'REPRAPFIRMWARE', 'RepRapFirmware (Duet boards)', value: 'reprapfirmware'
    value 'OTHER', 'Any other firmware', value: 'other'
  end
end
