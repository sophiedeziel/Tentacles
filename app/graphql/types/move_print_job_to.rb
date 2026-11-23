# frozen_string_literal: true

module Types
  class MovePrintJobTo < Base::Enum
    description 'Where movePrintJob puts a print job, among the print jobs still in the queue'

    value 'TOP', 'First in the queue', value: 'top'
    value 'BOTTOM', 'Last in the queue', value: 'bottom'
  end
end
