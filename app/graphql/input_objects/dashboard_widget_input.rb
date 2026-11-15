# frozen_string_literal: true

module InputObjects
  class DashboardWidgetInput < Base::InputObject
    description 'A dashboard widget (see DashboardWidget)'

    argument :id, ID, required: false, description: 'Null for a new widget'
    argument :type, Types::DashboardWidgetType, required: true
    argument :width_units, Integer, required: true, description: 'Grid columns spanned, 1 to 4'
    argument :height_units, Integer, required: true, description: 'Grid rows spanned, 1 to 4'
    argument :printer_id, ID, required: false, description: 'Null for a Print Queue of all printers'
    argument :options, InputObjects::DashboardWidgetOptionsInput, required: true

    def options_match_type?
      options.widget_type == type
    end

    # As DashboardSection.replace_all! takes it
    def to_attributes
      { id:, type:, width_units:, height_units:, printer_id:, options: options.to_options }
    end
  end
end
