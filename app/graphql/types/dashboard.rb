# frozen_string_literal: true

module Types
  # A Hash: { sections: [::DashboardSection], updated_at: }. See .for.
  class Dashboard < Base::Object
    description 'The global dashboard layout: no users, the last save wins'
    # No field depends on the context, so dashboardChanged can broadcast them
    default_broadcastable true

    field :sections, [Types::DashboardSection], null: false,
                                                description: 'The first section holds the widgets above any ' \
                                                             'divider; every other section is a divider'
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true,
                                                        description: 'When the layout was last saved (null for ' \
                                                                     'the default layout, which is not saved)'

    # The saved layout, widgets and printers preloaded
    def self.saved
      sections = ::DashboardSection.includes(widgets: :printer).to_a
      { sections:, updated_at: sections.filter_map(&:updated_at).max }
    end
  end
end
