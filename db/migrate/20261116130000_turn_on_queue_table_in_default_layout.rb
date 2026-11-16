# frozen_string_literal: true

# A Print Queue at XL or XXL now starts with one row per printer and history on. The default layout's queue was
# saved with no options (`{}`, read as the old defaults), and the dashboard editor always saves every option, so
# `{}` means nobody has edited the layout: only those queues get the new defaults. A queue saved from the editor
# keeps its options, since turning the table off may have been on purpose.
class TurnOnQueueTableInDefaultLayout < ActiveRecord::Migration[8.1]
  TABLE_ON = '{"row_per_printer": true, "history": true}'
  BIG_QUEUES = "type = 'PrintQueueWidget' AND width_units = 4 AND height_units IN (2, 4)"

  def up
    execute <<~SQL.squish
      UPDATE dashboard_widgets SET options = CAST('#{TABLE_ON}' AS JSON)
      WHERE #{BIG_QUEUES} AND JSON_LENGTH(options) = 0
    SQL
  end

  # Only this migration (and the new default layout) stores exactly these two options: the editor saves all four
  def down
    execute <<~SQL.squish
      UPDATE dashboard_widgets SET options = CAST('{}' AS JSON)
      WHERE #{BIG_QUEUES} AND options = CAST('#{TABLE_ON}' AS JSON)
    SQL
  end
end
