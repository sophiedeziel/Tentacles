# frozen_string_literal: true

# The models moved into domain namespaces: PrinterWidget → Dashboard::PrinterWidget, FileRecord → Library::Item, ...
# Rails stores some class names in the database: the STI `type` of dashboard_widgets and the polymorphic `_type` of
# printer_jobs (the file a job prints) and active_storage_attachments (the uploaded file). The tables keep their names.
class RenameStoredClassNamesToDomainNamespaces < ActiveRecord::Migration[8.1]
  # [table, column, class name before, class name after]
  RENAMES = [
    %w[dashboard_widgets type PrinterWidget Dashboard::PrinterWidget],
    %w[dashboard_widgets type PrintQueueWidget Dashboard::PrintQueueWidget],
    %w[printer_jobs executable_type FileRecord Library::Item],
    %w[active_storage_attachments record_type FileRecord Library::Item]
  ].freeze

  def up
    RENAMES.each { |table, column, before, after| rename_class(table, column, from: before, to: after) }
  end

  def down
    RENAMES.each { |table, column, before, after| rename_class(table, column, from: after, to: before) }
  end

  private

  # Plain SQL: the models may not match this migration's version of the schema, and updated_at stays as it was
  def rename_class(table, column, from:, to:)
    execute(<<~SQL.squish)
      UPDATE #{connection.quote_table_name(table)} SET #{connection.quote_column_name(column)} = #{connection.quote(to)}
      WHERE #{connection.quote_column_name(column)} = #{connection.quote(from)}
    SQL
  end
end
