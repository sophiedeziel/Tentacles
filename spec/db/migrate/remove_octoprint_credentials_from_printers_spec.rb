# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261116120000_remove_octoprint_credentials_from_printers')

RSpec.describe RemoveOctoprintCredentialsFromPrinters do
  let(:connection) { ActiveRecord::Base.connection }
  let(:migration) { described_class.new.tap { |migration| migration.verbose = false } }
  # The migration's own model: the spec keeps working when Printer changes
  let(:printers) { described_class::MigrationPrinter }

  # MySQL commits the test transaction on every ALTER TABLE: the printers are deleted by hand instead
  self.use_transactional_tests = false

  # The test schema has no OctoPrint columns: put them back as the previous release had them, and leave the schema
  # and the printers as they were afterwards, even when an example or `up` fails
  around do |example|
    migration.down
    example.run
  ensure
    printers.delete_all
    begin
      migration.up if octoprint_columns?
    ensure
      printers.reset_column_information
      Printer.reset_column_information
    end
  end

  def octoprint_columns?
    connection.column_exists?(:printers, :octoprint_uri) && connection.column_exists?(:printers, :octoprint_key)
  end

  # A printer as a release saved it, with the given columns
  def insert_printer(**columns)
    columns = { backend: 'octoprint', created_at: '2020-01-01 00:00:00', updated_at: '2020-01-01 00:00:00' }
              .merge(columns)
    connection.execute("INSERT INTO printers (#{columns.keys.join(', ')}) " \
                       "VALUES (#{columns.values.map { |value| connection.quote(value) }.join(', ')})")
    connection.select_value('SELECT LAST_INSERT_ID()')
  end

  # `secret` encrypted with other keys, like after SECRET_KEY_BASE changed
  def unreadable_secret
    key_provider = ActiveRecord::Encryption::DerivedSecretKeyProvider.new('another secret key base')
    ActiveRecord::Encryption::Encryptor.new.encrypt('OLDKEY', key_provider:)
  end

  def encrypted(secret)
    ActiveRecord::Encryption::Encryptor.new.encrypt(secret)
  end

  def stored_secret(id)
    connection.select_value("SELECT secret FROM printers WHERE id = #{id}")
  end

  describe '#up' do
    let!(:legacy_id) do
      insert_printer(name: 'Ender 3', octoprint_uri: 'http://octopi.local/', octoprint_key: 'A8DDB1359AAB')
    end
    let!(:blank_id) { insert_printer(name: 'Blank') }
    let!(:current_id) do
      insert_printer(name: 'Voron', uri: 'http://voron.local/', secret: encrypted('NEWKEY'),
                     octoprint_uri: 'http://voron.local/', octoprint_key: 'NEWKEY')
    end
    let!(:unreadable_id) do
      insert_printer(name: 'Prusa i3', uri: 'http://prusa.local/', secret: unreadable_secret,
                     octoprint_uri: 'http://prusa.local/', octoprint_key: 'MIRROREDKEY')
    end
    let!(:unreadable_without_uri_id) do
      insert_printer(name: 'CR-10', secret: unreadable_secret, octoprint_uri: 'http://cr10.local/',
                     octoprint_key: 'CR10KEY')
    end
    let!(:prusalink_id) do
      insert_printer(name: 'Prusa MK4', backend: 'prusalink', uri: 'http://prusa-mk4.local', secret: unreadable_secret)
    end
    let!(:prusalink_secret) { stored_secret(prusalink_id) }

    before { migration.up }

    it 'drops the OctoPrint columns' do
      expect(octoprint_columns?).to be false
    end

    it "first copies the URI and the API key of the printers that don't have them, encrypting the key" do
      expect(printers.find(legacy_id)).to have_attributes(uri: 'http://octopi.local/', secret: 'A8DDB1359AAB')
      expect(stored_secret(legacy_id)).not_to include('A8DDB1359AAB')
    end

    it "replaces a secret that can't be decrypted with the API key the mirror kept" do
      expect(printers.find(unreadable_id)).to have_attributes(uri: 'http://prusa.local/', secret: 'MIRROREDKEY')
      expect(printers.find(unreadable_without_uri_id)).to have_attributes(uri: 'http://cr10.local/',
                                                                          secret: 'CR10KEY')
    end

    it 'keeps the printers that have readable credentials, or none at all, as they were' do
      expect(printers.find(current_id)).to have_attributes(uri: 'http://voron.local/', secret: 'NEWKEY')
      expect(printers.find(blank_id)).to have_attributes(uri: nil, secret: nil)
    end

    it 'leaves PrusaLink printers alone' do
      expect(stored_secret(prusalink_id)).to eq prusalink_secret
    end

    it 'does not touch updated_at' do
      expect(printers.find(legacy_id).updated_at).to eq Time.utc(2020, 1, 1)
      expect(printers.find(unreadable_id).updated_at).to eq Time.utc(2020, 1, 1)
    end
  end

  describe '#down' do
    let!(:octoprint_id) { insert_printer(name: 'Ender 3', uri: 'http://octopi.local/', secret: encrypted('KEY')) }
    let!(:unreadable_id) { insert_printer(name: 'Prusa i3', uri: 'http://prusa.local/', secret: unreadable_secret) }
    let!(:prusalink_id) do
      insert_printer(name: 'Prusa MK4', backend: 'prusalink', uri: 'http://prusa-mk4.local', secret: encrypted('pw'))
    end

    before do
      migration.up
      migration.down
      printers.reset_column_information
    end

    it "puts the OctoPrint printers' URI and API key back in plain text, for the previous release" do
      expect(printers.find(octoprint_id)).to have_attributes(octoprint_uri: 'http://octopi.local/',
                                                             octoprint_key: 'KEY')
    end

    it "leaves the API key empty when the secret can't be decrypted" do
      expect(printers.find(unreadable_id)).to have_attributes(octoprint_uri: 'http://prusa.local/', octoprint_key: nil)
    end

    it 'never stores the password of a PrusaLink printer in plain text' do
      expect(printers.find(prusalink_id)).to have_attributes(octoprint_uri: nil, octoprint_key: nil)
    end
  end
end
