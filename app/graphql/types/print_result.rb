# frozen_string_literal: true

module Types
  class PrintResult < Base::Enum
    description 'How a print ended'

    value 'COMPLETED', 'Printed', value: 'completed'
    value 'FAILED', 'Failed (an error on the printer, or the file could not be sent)', value: 'error'
    value 'CANCELLED', 'Cancelled', value: 'cancelled'
  end
end
