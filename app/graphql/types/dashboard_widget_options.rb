# frozen_string_literal: true

module Types
  class DashboardWidgetOptions < Base::Union
    description "A dashboard widget's options, by widget type"

    possible_types Types::PrinterWidgetOptions, Types::PrintQueueWidgetOptions

    # `object` is the widget (see Dashboard::Widget#options)
    def self.resolve_type(object, _context)
      object.is_a?(::Dashboard::PrinterWidget) ? Types::PrinterWidgetOptions : Types::PrintQueueWidgetOptions
    end
  end
end
