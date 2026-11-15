# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Active Record encryption' do
  let(:config) { ActiveRecord::Encryption.config }

  it 'derives the keys with SHA256, whatever load_defaults says' do
    expect(config.hash_digest_class).to eq OpenSSL::Digest::SHA256
  end

  it 'does not decrypt with SHA1 keys' do
    expect(config.previous_schemes).to be_empty
  end

  it 'encrypts then decrypts a secret' do
    encryptor = ActiveRecord::Encryption::Encryptor.new
    ciphertext = encryptor.encrypt('A8DDB1359AAB')

    expect(ciphertext).not_to include('A8DDB1359AAB')
    expect(encryptor.decrypt(ciphertext)).to eq 'A8DDB1359AAB'
  end

  it "encrypts then decrypts a printer's secret" do
    printer = create(:printer, secret: 'A8DDB1359AAB')
    stored = Printer.connection.select_value("SELECT secret FROM printers WHERE id = #{printer.id}")

    expect(stored).not_to include('A8DDB1359AAB')
    expect(Printer.find(printer.id).secret).to eq 'A8DDB1359AAB'
  end
end
