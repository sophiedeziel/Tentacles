class CreatePrintfiles < ActiveRecord::Migration[7.0]
  def change
    create_table :printfiles do |t|
      t.string :filename
      t.string :notes

      t.timestamps
    end
  end
end
