# frozen_string_literal: true

class AddArchivalToFiles < ActiveRecord::Migration[7.0]
  def change
    change_table :files, bulk: true do |t|
      t.boolean :is_not_archived, default: true, null: false
      t.datetime :archived_at, default: nil
    end
  end
end
