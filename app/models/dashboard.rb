# typed: true
# frozen_string_literal: true

# The dashboard's domain: its sections and their widgets. One global layout, no users: the last save wins.
#
#   Dashboard::Section.ensure_default!
#   Dashboard::Section.includes(widgets: :printer) # the layout, in order
#   Dashboard::PrinterWidget.new(printer:, width_units: 2, height_units: 1, position: 0)
#
# The tables keep their dashboard_ prefix (dashboard_sections, dashboard_widgets).
module Dashboard
  def self.table_name_prefix = 'dashboard_'
end
