# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261115180000_add_backend_and_credentials_to_printers')

RSpec.describe AddBackendAndCredentialsToPrinters do
  let(:connection) { ActiveRecord::Base.connection }
  # The migration's own model: the spec keeps working when Printer changes
  let(:printers) { described_class::MigrationPrinter }

  # A printer as the previous release saved it: only the OctoPrint columns are set
  def insert_legacy_printer(name, uri, key)
    values = [name, uri, key, '2020-01-01 00:00:00', '2020-01-01 00:00:00'].map { |value| connection.quote(value) }
    connection.execute(
      "INSERT INTO printers (name, octoprint_uri, octoprint_key, created_at, updated_at) VALUES (#{values.join(', ')})"
    )
    connection.select_value('SELECT LAST_INSERT_ID()')
  end

  def stored_secret(id)
    connection.select_value("SELECT secret FROM printers WHERE id = #{id}")
  end

  describe '#backfill_credentials' do
    let!(:legacy_id) { insert_legacy_printer('Prusa MK4', 'http://octopi.local/', 'A8DDB1359AAB') }
    let!(:blank_id) { insert_legacy_printer('Blank', nil, nil) }

    before { described_class.new.backfill_credentials }

    it 'copies the URI and the API key, and sets the backend to octoprint' do
      expect(printers.find(legacy_id)).to have_attributes(backend: 'octoprint', uri: 'http://octopi.local/',
                                                          secret: 'A8DDB1359AAB', username: nil)
    end

    it 'stores the API key encrypted' do
      expect(stored_secret(legacy_id)).to be_present
      expect(stored_secret(legacy_id)).not_to include('A8DDB1359AAB')
    end

    it 'keeps printers without credentials as they were' do
      expect(printers.find(blank_id)).to have_attributes(backend: 'octoprint', uri: nil, secret: nil)
    end

    it 'keeps the OctoPrint columns' do
      expect(printers.find(legacy_id)).to have_attributes(octoprint_uri: 'http://octopi.local/',
                                                          octoprint_key: 'A8DDB1359AAB')
    end

    it 'does not touch updated_at' do
      expect(printers.find(legacy_id).updated_at).to eq Time.utc(2020, 1, 1)
    end
  end
end
