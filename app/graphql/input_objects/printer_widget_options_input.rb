# frozen_string_literal: true

module InputObjects
  class PrinterWidgetOptionsInput < Base::InputObject
    description "A Printer widget's options (see PrinterWidgetOptions). A missing option takes its default."

    argument :camera, Boolean, required: false
    argument :time_left, Boolean, required: false
    argument :temperatures, Boolean, required: false
    argument :up_next, Boolean, required: false
    argument :controls, Boolean, required: false
  end
end
