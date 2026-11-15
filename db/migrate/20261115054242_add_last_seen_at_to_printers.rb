# frozen_string_literal: true

class AddLastSeenAtToPrinters < ActiveRecord::Migration[8.1]
  def change
    add_column :printers, :last_seen_at, :datetime
  end
end
