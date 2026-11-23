# frozen_string_literal: true

module Types
  class BedClearedBy < Base::Enum
    description 'Who confirmed the bed was cleared after a print'

    value 'PERSON', 'A person (Bed Cleared)', value: 'person'
    value 'AUTOMATIC', 'The printer, which clears its own bed', value: 'automatic'
  end
end
