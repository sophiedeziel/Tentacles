class CreateLabels < ActiveRecord::Migration[7.1]
  def change
    create_table :labels do |t|
      t.string :name, null: false
      t.string :color, null: false

      t.timestamps
    end
  end
end
