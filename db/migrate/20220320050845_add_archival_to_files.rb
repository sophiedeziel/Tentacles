class AddArchivalToFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :files, :is_not_archived, :boolean, default: true
    add_column :files, :archived_at, :datetime
  end
end
