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
end
