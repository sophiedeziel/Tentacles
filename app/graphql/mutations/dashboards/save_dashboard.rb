# frozen_string_literal: true

module Mutations
  module Dashboards
    class SaveDashboard < Base::Mutation
      description 'Replaces the whole dashboard layout (the last save wins) and pushes it to dashboardChanged. ' \
                  'Rows with an id are updated, rows without one are created, and missing rows are destroyed.'

      argument :sections, [InputObjects::DashboardSectionInput], required: true, description: 'In order'

      field :dashboard, Types::Dashboard, null: true, description: 'The saved layout, null when it is invalid'
      field :errors, [String], null: false

      # A concurrent save or printer deletion: nothing was saved
      CONFLICTS = [ActiveRecord::LockWaitTimeout, ActiveRecord::Deadlocked, ActiveRecord::InvalidForeignKey].freeze

      def resolve(sections:)
        attributes = sections.map(&:to_attributes)
        ::Dashboard::Section::Replacement.check_limits!(attributes)
        mismatches = options_mismatches(sections)
        return failure(mismatches) if mismatches.any?

        ::Dashboard::Section.replace_all!(attributes)
        broadcast
        { dashboard: Types::Dashboard.saved, errors: [] }
      rescue ::Dashboard::Section::InvalidLayout => e
        failure(e.messages)
      rescue *CONFLICTS
        failure(['The dashboard changed while saving, try again'])
      end

      private

      def failure(errors)
        { dashboard: nil, errors: }
      end

      def options_mismatches(sections)
        sections.each_with_index.flat_map do |section, index|
          section.widgets.each_with_index.filter_map do |widget, position|
            next if widget.options_match_type?

            "Widget #{position + 1} in section #{index + 1}: options don't match the widget type"
          end
        end
      end

      # The layout is saved by now: a push that fails only leaves other screens behind until their next load
      def broadcast
        TentaclesSchema.subscriptions.trigger(:dashboard_changed, {}, {})
      rescue StandardError => e
        Rails.logger.error("[saveDashboard] Could not push dashboardChanged: #{e.class}: #{e.message}")
      end
    end
  end
end
