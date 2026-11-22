# frozen_string_literal: true

module Types
  class DashboardWidgetType < Base::Enum
    graphql_name 'DashboardWidgetType' # graphql-ruby would drop the "Type" suffix
    description 'The kind of a dashboard widget'

    value 'PRINTER', "One printer's live state", value: 'Dashboard::PrinterWidget'
    value 'PRINT_QUEUE', 'What prints next, for all printers or one', value: 'Dashboard::PrintQueueWidget'
  end
end
