# frozen_string_literal: true

module Types
  class PrinterStateFamily < Base::Enum
    description "A printer's state, as reported by its server, grouped into a small set of families"

    DESCRIPTIONS = {
      ::Printer::StateFamily::Printing => 'Starting, printing, sending to the SD card, resuming or finishing a job',
      ::Printer::StateFamily::Paused => 'Pausing or paused',
      ::Printer::StateFamily::Cancelling => 'Cancelling the current job',
      ::Printer::StateFamily::Operational => 'Connected and idle, ready to print',
      ::Printer::StateFamily::Connecting => 'Opening, detecting or connecting to the serial connection',
      ::Printer::StateFamily::Error => 'In error, offline after an error, or waiting for the user outside of a job',
      ::Printer::StateFamily::Offline => "Offline, unknown state, or the printer's server unreachable"
    }.freeze

    ::Printer::StateFamily.each_value do |family|
      value family.serialize, DESCRIPTIONS.fetch(family), value: family
    end
  end
end
