# frozen_string_literal: true

module Types
  # A ::PrintQueue::Forecast::Outcome
  class WhatHappensNext < Base::Object
    description 'What happens next to a waiting print job, computed for the whole queue at once so the queue page ' \
                'and the printer page agree with the dispatcher. Computed as if dispatch were running: ' \
                'dispatchPaused says it waits for dispatch to resume first.'

    field :kind, Types::WhatHappensNextKind, null: false
    field :printer, Types::Printer, null: true,
                                    description: 'The printer, for AFTER_CURRENT_PRINT, AFTER_BED_CLEARED, STARTING ' \
                                                 'and BATCH_ON_PRINTER. Null for the other kinds.'
    field :jobs_ahead, Integer, null: false,
                                description: 'How many other print jobs the printer takes before this one: 0 when ' \
                                             'it is the first the printer takes (always 0 without a printer, and ' \
                                             'for STARTING and BATCH_ON_PRINTER). A batch ahead counts once.'
    field :dispatch_paused, Boolean, null: false,
                                     description: 'Whether it waits for dispatch to resume first: dispatch is paused ' \
                                                  'and it is not ON_HOLD, nor a copy already handed to its printer ' \
                                                  '(STARTING with no copy left to start, which starts anyway)'
  end
end
