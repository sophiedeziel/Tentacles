# frozen_string_literal: true

class CreatePrinters < ActiveRecord::Migration[7.0]
  def change
    create_table :printers do |t|
      t.string :name
      t.string :octoprint_uri
      t.string :octoprint_key

      t.timestamps
    end
  end
end
