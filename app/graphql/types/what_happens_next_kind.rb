# frozen_string_literal: true

module Types
  # The kinds of ::PrintQueue::Forecast (see its class comment for how each is decided)
  class WhatHappensNextKind < Base::Enum
    description 'What happens next to a waiting print job. The page turns the kind into words.'

    value 'ON_HOLD', 'Held: it waits until it is released', value: :on_hold
    value 'DISPATCH_PAUSED', 'Dispatch is paused: nothing starts until it resumes', value: :dispatch_paused
    value 'BLOCKED', 'No printer that takes jobs can print it as loaded: a filament change is needed, or no ' \
                     'printer can print it at all (see eligiblePrinters)', value: :blocked
    value 'NEXT_READY_PRINTER', 'Each copy goes to the next ready printer, not assigned yet', value: :next_ready_printer
    value 'AFTER_CURRENT_PRINT', 'The printer takes it when its current print finishes', value: :after_current_print
    value 'AFTER_BED_CLEARED', 'The printer takes it once its bed is cleared', value: :after_bed_cleared
    value 'STARTING', 'A copy is handed to the printer, or is on the next dispatch pass', value: :starting
    value 'BATCH_ON_PRINTER', 'A same-printer batch: the printer prints the next copy when the current one finishes',
          value: :batch_on_printer
    value 'BATCH_FIRST_READY_PRINTER', 'A same-printer batch not started yet: the first ready printer takes all ' \
                                       'the copies', value: :batch_first_ready_printer
  end
end
