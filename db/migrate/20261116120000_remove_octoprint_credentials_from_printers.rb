# frozen_string_literal: true

# Drops `octoprint_uri` and `octoprint_key`, replaced by `uri` and `secret` (see AddBackendAndCredentialsToPrinters).
#
# Up first copies what only the old columns still hold into `uri` and `secret`, for the OctoPrint printers:
# - the URI and the API key of the printers added by a release older than the backend column, after a rollback to it;
# - the API key of the printers whose `secret` can't be decrypted (e.g. SECRET_KEY_BASE changed): the mirror kept the
#   plain-text key, the only one still usable.
# Down puts the columns back from `uri` and `secret` for the OctoPrint printers, so that an older release still finds
# its credentials.
class RemoveOctoprintCredentialsFromPrinters < ActiveRecord::Migration[8.1]
  # A minimal model, so that this migration doesn't depend on the Printer model as it evolves.
  # `encrypts` reads and writes `secret` the way Printer does.
  class MigrationPrinter < ActiveRecord::Base
    self.table_name = 'printers'
    self.record_timestamps = false

    encrypts :secret
  end

  def up
    backfill_credentials

    change_table :printers, bulk: true do |t|
      t.remove :octoprint_uri, :octoprint_key
    end
  end

  def down
    change_table :printers, bulk: true do |t|
      t.string :octoprint_uri
      t.string :octoprint_key
    end

    restore_octoprint_credentials
  end

  # update_columns, not update!: saving compares the new secret with the stored one, which raises when the stored
  # one can't be decrypted. update_columns still encrypts it.
  def backfill_credentials
    MigrationPrinter.reset_column_information
    MigrationPrinter.where(backend: 'octoprint').find_each do |printer|
      changes = {}
      changes[:uri] = printer.octoprint_uri if printer.uri.nil? && printer.octoprint_uri.present?
      changes[:secret] = printer.octoprint_key if printer.octoprint_key.present? && readable_secret(printer).nil?
      printer.update_columns(changes) if changes.any? # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def restore_octoprint_credentials
    MigrationPrinter.reset_column_information
    MigrationPrinter.where(backend: 'octoprint').find_each do |printer|
      printer.update_columns(octoprint_uri: printer.uri, octoprint_key: readable_secret(printer)) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  private

  # nil when there is none or when it can't be decrypted
  def readable_secret(printer)
    printer.secret
  rescue ActiveRecord::Encryption::Errors::Decryption
    nil
  end
end
