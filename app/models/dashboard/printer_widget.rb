# typed: true
# frozen_string_literal: true

module Dashboard
  # One printer's live state. Not Dashboard::Widget::Printer: `belongs_to :printer` would resolve to it.
  #
  #   Dashboard::PrinterWidget.create!(section:, printer:, width_units: 2, height_units: 1, position: 0)
  class PrinterWidget < Widget
    widget_options camera: true, time_left: true, temperatures: true, up_next: true, controls: true
    widget_spans [1, 1], [2, 1], [2, 2], [4, 2]

    validates :printer, presence: true
  end
end
