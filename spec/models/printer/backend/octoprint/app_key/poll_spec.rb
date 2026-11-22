# frozen_string_literal: true

require 'rails_helper'
require 'support/app_key_request_helpers'

# OctoPrint's Application Keys plugin is stubbed with WebMock, without VCR
RSpec.describe Printer::Backend::Octoprint::AppKey::Poll do
  include AppKeyRequestHelpers

  let(:app_token) { AppKeyRequestHelpers::APP_TOKEN }
  let(:api_key) { AppKeyRequestHelpers::API_KEY }
  let(:endpoint) { "http://192.168.1.57/plugin/appkeys/request/#{app_token}" }
  let(:octoprint) { stub_request(:get, endpoint) }
  let(:poll) { described_class.new(url: 'http://192.168.1.57/', app_token:) }

  def json(status, body)
    { status:, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  # The error #save! raises, and that #save puts in errors[:base] instead
  shared_examples 'an error' do |error_class, message|
    it "raises #{error_class} from #save!" do
      expect { poll.save! }.to raise_error(error_class, message)
    end

    it 'returns false from #save, with the message in errors[:base] and no decision' do
      expect(poll.save).to be(false)
      expect(poll.errors[:base]).to eq([message])
      expect(poll).to have_attributes(decision: nil, api_key: nil)
    end

    it 'never puts the app token or the API key in the message' do
      poll.save

      expect(poll.errors.full_messages.join).not_to include(app_token)
      expect(poll.errors.full_messages.join).not_to include(api_key)
    end
  end

  context 'while the user has not decided (202)' do
    before { octoprint.to_return(json(202, message: 'Awaiting decision')) }

    it 'asks OctoPrint about the request of the app token, and is waiting without a key' do
      expect(poll.save).to be(true)
      expect(poll).to have_attributes(decision: :waiting, api_key: nil)
      expect(octoprint).to have_been_made.once
    end
  end

  context 'when the user denied it, or it expired (404)' do
    before { octoprint.to_return(status: 404) }

    it 'is denied, without a key' do
      expect(poll.save).to be(true)
      expect(poll).to have_attributes(decision: :denied, api_key: nil)
    end
  end

  context 'when the user approved it (200)' do
    before { octoprint.to_return(json(200, api_key:)) }

    it 'is approved, with the new key' do
      expect(poll.save).to be(true)
      expect(poll).to have_attributes(decision: :approved, api_key:)
    end

    it 'is what .create! returns' do
      expect(described_class.create!(url: 'http://192.168.1.57/', app_token:))
        .to have_attributes(decision: :approved, api_key:)
    end
  end

  context 'when OctoPrint answers another status' do
    before { octoprint.to_return(json(500, error: "Broken: #{AppKeyRequestHelpers::API_KEY}")) }

    it_behaves_like 'an error', Printer::Backend::Error, 'OctoPrint at http://192.168.1.57/ answered HTTP 500'
  end

  context 'when OctoPrint times out' do
    before { octoprint.to_timeout }

    it_behaves_like 'an error', Printer::Backend::Unreachable, 'Could not reach OctoPrint at http://192.168.1.57/'
  end

  context 'when the connection fails' do
    before { octoprint.to_raise(Faraday::ConnectionFailed.new("Failed to open TCP connection to #{endpoint}")) }

    it_behaves_like 'an error', Printer::Backend::Unreachable, 'Could not reach OctoPrint at http://192.168.1.57/'
  end

  context 'when the approval is not JSON' do
    before { octoprint.to_return(status: 200, body: "api_key=#{AppKeyRequestHelpers::API_KEY}") }

    it_behaves_like 'an error', Printer::Backend::Error, 'http://192.168.1.57/ does not answer like OctoPrint'
  end

  context 'when the approval is JSON but not an object' do
    before { octoprint.to_return(json(200, [AppKeyRequestHelpers::API_KEY])) }

    it_behaves_like 'an error', Printer::Backend::Error, 'http://192.168.1.57/ does not answer like OctoPrint'
  end

  context 'when the approval has no key' do
    before { octoprint.to_return(json(200, message: 'Approved')) }

    it_behaves_like 'an error', Printer::Backend::Error, 'http://192.168.1.57/ does not answer like OctoPrint'
  end

  describe 'validations' do
    it 'needs a URL' do
      poll = described_class.new(app_token:)

      expect(poll.save).to be(false)
      expect(poll.errors.full_messages).to eq(["Url can't be blank"])
    end

    it 'needs an app token' do
      poll = described_class.new(url: 'http://192.168.1.57/', app_token: '')

      expect(poll.save).to be(false)
      expect(poll.errors.full_messages).to eq(["App token can't be blank"])
    end

    it 'calls nothing when invalid, and #save! raises' do
      poll = described_class.new

      expect { poll.save! }.to raise_error(ActiveModel::ValidationError)
      expect(a_request(:any, /.*/)).not_to have_been_made
    end
  end
end
