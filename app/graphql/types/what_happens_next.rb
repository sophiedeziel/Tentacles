# frozen_string_literal: true

module Types
  # A ::PrintQueue::Forecast::Outcome
  class WhatHappensNext < Base::Object
    description 'What happens next to a waiting print job, computed for the whole queue at once so the queue page ' \
                'and the printer page agree with the dispatcher'

    field :kind, Types::WhatHappensNextKind, null: false
    field :printer, Types::Printer, null: true,
                                    description: 'The printer, for AFTER_CURRENT_PRINT, AFTER_BED_CLEARED, STARTING ' \
                                                 'and BATCH_ON_PRINTER. Null for the other kinds.'
  end
end
