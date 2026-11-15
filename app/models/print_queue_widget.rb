# typed: true
# frozen_string_literal: true

# What prints next, for one printer or all of them (no printer)
class PrintQueueWidget < DashboardWidget
  widget_options now_printing: true, start_next: true, row_per_printer: false, history: false
  widget_spans [1, 1], [2, 1], [2, 2], [4, 2], [4, 4]
end
