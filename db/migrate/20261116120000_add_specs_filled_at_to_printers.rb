# frozen_string_literal: true

# When a fill last read the printer's server (Printer::Specs#fill_specs_from_server), so that the monitor fills the
# printers that were unreachable when they were added. Left nil for the existing printers: nothing records whether a
# fill read their server, and the monitor reading it once more only fills the columns still nil.
class AddSpecsFilledAtToPrinters < ActiveRecord::Migration[8.1]
  def change
    add_column :printers, :specs_filled_at, :datetime, null: true
  end
end
