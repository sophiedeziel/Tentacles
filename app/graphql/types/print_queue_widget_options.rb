# frozen_string_literal: true

module Types
  # The options of a ::Dashboard::PrintQueueWidget (missing ones read as their default)
  class PrintQueueWidgetOptions < Base::Object
    description "A Print Queue widget's options"
    default_broadcastable true

    field :now_printing, Boolean, null: false, description: 'Show the current prints (M and up)'
    field :start_next, Boolean, null: false, description: 'Offer Start Next (L and up)'
    field :row_per_printer, Boolean, null: false, description: 'One row per printer, for all printers (XL and up)'
    field :history, Boolean, null: false, description: 'Show the finished jobs (XL and up)'
  end
end
