# typed: true
# frozen_string_literal: true

# One printer's live state
class PrinterWidget < DashboardWidget
  widget_options camera: true, time_left: true, temperatures: true, up_next: true, controls: true
  widget_spans [1, 1], [2, 1], [2, 2], [4, 2]

  validates :printer, presence: true
end
