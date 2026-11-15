# frozen_string_literal: true

# Printers get a backend (only "octoprint" for now) and backend-neutral credentials. `uri` and `secret` are copied
# from `octoprint_uri` and `octoprint_key`, which stay (and are kept in sync by Printer) until a later cleanup.
class AddBackendAndCredentialsToPrinters < ActiveRecord::Migration[8.1]
  # A minimal model, so that this migration doesn't depend on the Printer model as it evolves.
  # `encrypts` makes the backfilled secrets encrypted from the start.
  class MigrationPrinter < ActiveRecord::Base
    self.table_name = 'printers'
    self.record_timestamps = false

    encrypts :secret
  end

  def up
    change_table :printers, bulk: true do |t|
      t.string :backend, null: false, default: 'octoprint'
      t.string :uri
      t.string :username
      t.text :secret
    end

    backfill_credentials
  end

  def down
    change_table :printers, bulk: true do |t|
      t.remove :backend, :uri, :username, :secret
    end
  end

  def backfill_credentials
    MigrationPrinter.reset_column_information
    MigrationPrinter.where(uri: nil).find_each do |printer|
      printer.update!(uri: printer.octoprint_uri, secret: printer.octoprint_key)
    end
  end
end
