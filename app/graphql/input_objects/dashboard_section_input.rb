# frozen_string_literal: true

module InputObjects
  class DashboardSectionInput < Base::InputObject
    description 'A dashboard section (see DashboardSection)'

    argument :id, ID, required: false, description: 'Null for a new section'
    argument :title, String, required: false, description: "The divider's title, null for the first section"
    argument :widgets, [InputObjects::DashboardWidgetInput], required: true, description: 'In grid order'

    # As DashboardSection.replace_all! takes it
    def to_attributes
      { id:, title:, widgets: widgets.map(&:to_attributes) }
    end
  end
end
