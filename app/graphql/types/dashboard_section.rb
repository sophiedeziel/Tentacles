# frozen_string_literal: true

module Types
  # A ::DashboardSection
  class DashboardSection < Base::Object
    description 'A run of dashboard widgets, under a divider except for the first section'
    default_broadcastable true

    field :id, ID, null: true, description: 'Null in the default layout, which is not saved'
    field :title, String, null: true, description: "The divider's title, null for the first section"
    field :widgets, [Types::DashboardWidget], null: false, description: 'In grid order'
  end
end
