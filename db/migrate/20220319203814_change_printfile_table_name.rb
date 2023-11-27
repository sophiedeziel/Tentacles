# frozen_string_literal: true

class ChangePrintfileTableName < ActiveRecord::Migration[7.0]
  # rubocop:disable Rails/SkipsModelValidations
  def up
    rename_table :printfiles, :files
    ActiveStorage::Attachment
      .where(record_type: 'Printfile')
      .update_all(record_type: 'FileRecord')
  end

  def down
    rename_table :files, :printfiles
    ActiveStorage::Attachment
      .where(record_type: 'Printfile')
      .update_all(record_type: 'Printfile')
  end
  # rubocop:enable Rails/SkipsModelValidations
end
