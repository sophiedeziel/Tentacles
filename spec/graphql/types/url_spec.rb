# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Types::Url do
  describe '.coerce_input' do
    it 'accepts absolute http and https URLs' do
      expect(described_class.coerce_input('http://192.168.1.57/', nil)).to eq('http://192.168.1.57/')
      expect(described_class.coerce_input('https://octopi.local/api', nil)).to eq('https://octopi.local/api')
    end

    it 'lets a blank string through, for the presence validations' do
      expect(described_class.coerce_input('', nil)).to eq('')
      expect(described_class.coerce_input('  ', nil)).to eq('')
    end

    it 'refuses relative URLs, other schemes and garbage' do
      ['/printers', '192.168.1.57', 'ftp://host/file', 'file:///etc/passwd', 'http://',
       'http://bad host/'].each do |value|
        expect { described_class.coerce_input(value, nil) }.to raise_error(GraphQL::CoercionError), value
      end
    end
  end
end
