# frozen_string_literal: true

module Types
  class PrintStatus < Base::Enum
    description 'Where a print (a copy of a print job) is'

    value 'ENQUEUED', 'Handed to its printer, not started yet', value: 'enqueued'
    value 'ACTIVE', 'Under way: printing, paused or cancelling', value: 'active'
    value 'COMPLETED', 'Ended: printed', value: 'completed'
    value 'ERROR', 'Ended: failed', value: 'error'
    value 'CANCELLED', 'Ended: cancelled', value: 'cancelled'
  end
end
