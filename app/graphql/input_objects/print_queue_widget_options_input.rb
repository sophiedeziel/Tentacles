# frozen_string_literal: true

module InputObjects
  class PrintQueueWidgetOptionsInput < Base::InputObject
    description "A Print Queue widget's options (see PrintQueueWidgetOptions). A missing option takes its default."

    argument :now_printing, Boolean, required: false
    argument :start_next, Boolean, required: false
    argument :row_per_printer, Boolean, required: false
    argument :history, Boolean, required: false
  end
end
