# frozen_string_literal: true

module Types
  # A ::DashboardWidget (PrinterWidget or PrintQueueWidget)
  class DashboardWidget < Base::Object
    description 'A widget of the dashboard. S to XXL are UI names for its span: S 1×1, M 2×1, L 2×2, XL 4×2, XXL 4×4.'
    default_broadcastable true

    field :id, ID, null: true, description: 'Null in the default layout, which is not saved'
    field :type, Types::DashboardWidgetType, null: false
    field :width_units, Integer, null: false, description: 'Grid columns spanned, 1 to 4'
    field :height_units, Integer, null: false, description: 'Grid rows spanned, 1 to 4'
    field :printer, Types::Printer, null: true,
                                    description: 'The printer it shows; null for a Print Queue of all printers'
    field :options, Types::DashboardWidgetOptions, null: false,
                                                   description: 'Kept for every size: a smaller size ignores the ' \
                                                                'options it cannot show'

    # The union resolves the options' type from the widget's class
    def options
      object
    end
  end
end
