# frozen_string_literal: true

module Types
  # The results of a ::PrintQueue::Fit
  class FitResult < Base::Enum
    description 'How a printer fits a print job, the first that applies'

    value 'CANNOT', 'It can never print it: a hard limit (the bed, the height, the tools or the materials it prints)',
          value: :cannot
    value 'AFTER_RECONNECT', 'It can print it once it reconnects (and its filament is set, see reasons)',
          value: :after_reconnect
    value 'AFTER_FILAMENT_CHANGE', 'It can print it once the filament asked for is loaded',
          value: :after_filament_change
    value 'READY', 'It can print it with what is loaded', value: :ready
  end
end
