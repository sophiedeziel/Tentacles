# frozen_string_literal: true

module InputObjects
  class DashboardWidgetOptionsInput < Base::InputObject
    description "A dashboard widget's options: exactly one of them, matching the widget's type"
    one_of

    argument :printer, InputObjects::PrinterWidgetOptionsInput, required: false
    argument :print_queue, InputObjects::PrintQueueWidgetOptionsInput, required: false

    # The widget type (DashboardWidget#type) these options are for
    def widget_type
      printer ? 'PrinterWidget' : 'PrintQueueWidget'
    end

    # As stored in DashboardWidget#options; a null option takes its default, like a missing one
    def to_options
      (printer || print_queue).to_h.compact
    end
  end
end
