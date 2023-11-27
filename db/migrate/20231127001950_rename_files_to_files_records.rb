class RenameFilesToFilesRecords < ActiveRecord::Migration[7.0]
  # rubocop:disable Rails/SkipsModelValidations
  def up
    rename_table :files, :file_records
    ActiveStorage::Attachment
      .where(record_type: 'FileManager::File')
      .update_all(record_type: 'FileRecord')
  end

  def down
    rename_table :file_records, :files
    ActiveStorage::Attachment
      .where(record_type: 'FileRecord')
      .update_all(record_type: 'FileManager::File')
  end
  # rubocop:enable Rails/SkipsModelValidations
end
