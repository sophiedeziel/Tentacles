# frozen_string_literal: true

module Types
  class PrinterStateFamily < Base::Enum
    description "A printer's OctoPrint state, grouped into a small set of families"

    DESCRIPTIONS = {
      ::PrinterStateFamily::Printing => 'Starting, printing, sending to the SD card, resuming or finishing a job',
      ::PrinterStateFamily::Paused => 'Pausing or paused',
      ::PrinterStateFamily::Cancelling => 'Cancelling the current job',
      ::PrinterStateFamily::Operational => 'Connected and idle, ready to print',
      ::PrinterStateFamily::Connecting => 'Opening, detecting or connecting to the serial connection',
      ::PrinterStateFamily::Error => 'In error, or offline after an error',
      ::PrinterStateFamily::Offline => 'Offline, unknown state, or OctoPrint unreachable'
    }.freeze

    ::PrinterStateFamily.each_value do |family|
      value family.serialize, DESCRIPTIONS.fetch(family), value: family
    end
  end
end
