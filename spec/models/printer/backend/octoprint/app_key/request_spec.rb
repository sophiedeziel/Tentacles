# frozen_string_literal: true

require 'rails_helper'
require 'support/app_key_request_helpers'

# OctoPrint's Application Keys plugin is stubbed with WebMock, without VCR
RSpec.describe Printer::Backend::Octoprint::AppKey::Request do
  include AppKeyRequestHelpers

  let(:app_token) { AppKeyRequestHelpers::APP_TOKEN }
  let(:auth_dialog) { "http://192.168.1.57/plugin/appkeys/auth/#{app_token}" }
  let(:endpoint) { 'http://192.168.1.57/plugin/appkeys/request' }
  let(:octoprint) { stub_request(:post, endpoint) }
  let(:request) { described_class.new(url: 'http://192.168.1.57/') }

  def json(status, body)
    { status:, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  # The error #save! raises, and that #save puts in errors[:base] instead
  shared_examples 'an error' do |error_class, message|
    it "raises #{error_class} from #save!" do
      expect { request.save! }.to raise_error(error_class, message)
    end

    it 'returns false from #save, with the message in errors[:base] and no app token' do
      expect(request.save).to be(false)
      expect(request.errors[:base]).to eq([message])
      expect(request.app_token).to be_nil
    end

    it 'never puts the app token in the message' do
      request.save

      expect(request.errors.full_messages.join).not_to include(app_token)
    end
  end

  describe '.url' do
    it 'builds the URL of an IPv4 address' do
      expect(described_class.url(IPAddr.new('192.168.1.57'))).to eq('http://192.168.1.57/')
    end

    it 'puts an IPv6 address in brackets' do
      expect(described_class.url(IPAddr.new('fd00::57'))).to eq('http://[fd00::57]/')
    end
  end

  context 'when OctoPrint takes the request (201)' do
    before { octoprint.to_return(json(201, app_token:, auth_dialog:)) }

    it 'asks for a key for Tentacles, as JSON' do
      request.save!

      expect(a_request(:post, endpoint)
        .with(body: { app: 'Tentacles' }.to_json, headers: { 'Content-Type' => 'application/json' }))
        .to have_been_made.once
    end

    it 'reads the app token and the dialog where the user approves it' do
      expect(request.save).to be(true)
      expect(request).to have_attributes(app_token:, auth_dialog_url: auth_dialog)
      expect(request.errors).to be_empty
    end

    it 'is what .create! returns' do
      expect(described_class.create!(url: 'http://192.168.1.57/'))
        .to have_attributes(app_token:, auth_dialog_url: auth_dialog)
    end
  end

  context 'when OctoPrint has no dialog to point to (before 1.8)' do
    it 'leaves auth_dialog_url nil when it is absent' do
      octoprint.to_return(json(201, app_token:))
      request.save!

      expect(request).to have_attributes(app_token:, auth_dialog_url: nil)
    end

    it 'leaves auth_dialog_url nil when it is blank' do
      octoprint.to_return(json(201, app_token:, auth_dialog: ''))
      request.save!

      expect(request).to have_attributes(app_token:, auth_dialog_url: nil)
    end
  end

  context 'when OctoPrint got too many requests (429)' do
    before { octoprint.to_return(json(429, error: 'Too many requests')) }

    it_behaves_like 'an error', Printer::Backend::Error,
                    'OctoPrint at http://192.168.1.57/ got too many requests. Try again in a minute.'
  end

  context 'when OctoPrint refuses the request (any other status)' do
    before { octoprint.to_return(json(404, error: "Not found: #{AppKeyRequestHelpers::APP_TOKEN}")) }

    it_behaves_like 'an error', Printer::Backend::Error,
                    'OctoPrint at http://192.168.1.57/ refused the request (HTTP 404). Is its Application Keys ' \
                    'plugin enabled?'
  end

  context 'when OctoPrint times out' do
    before { octoprint.to_timeout }

    it_behaves_like 'an error', Printer::Backend::Unreachable, 'Could not reach OctoPrint at http://192.168.1.57/'
  end

  context 'when the connection fails' do
    before { octoprint.to_raise(Faraday::ConnectionFailed.new('Connection refused')) }

    it_behaves_like 'an error', Printer::Backend::Unreachable, 'Could not reach OctoPrint at http://192.168.1.57/'
  end

  context 'when the answer is not JSON' do
    before { octoprint.to_return(status: 201, body: '<html>Hello</html>') }

    it_behaves_like 'an error', Printer::Backend::Error, 'http://192.168.1.57/ does not answer like OctoPrint'
  end

  context 'when the answer is JSON but not an object' do
    before { octoprint.to_return(json(201, [app_token])) }

    it_behaves_like 'an error', Printer::Backend::Error, 'http://192.168.1.57/ does not answer like OctoPrint'
  end

  context 'when the answer has no app token' do
    before { octoprint.to_return(json(201, auth_dialog:)) }

    it_behaves_like 'an error', Printer::Backend::Error, 'http://192.168.1.57/ does not answer like OctoPrint'
  end

  context 'when the app token is not a string' do
    before { octoprint.to_return(json(201, app_token: 42)) }

    it_behaves_like 'an error', Printer::Backend::Error, 'http://192.168.1.57/ does not answer like OctoPrint'
  end

  context 'when the app token is empty' do
    before { octoprint.to_return(json(201, app_token: '', auth_dialog:)) }

    it_behaves_like 'an error', Printer::Backend::Error, 'http://192.168.1.57/ does not answer like OctoPrint'
  end

  context 'when the app token is blank' do
    before { octoprint.to_return(json(201, app_token: " \t", auth_dialog:)) }

    it_behaves_like 'an error', Printer::Backend::Error, 'http://192.168.1.57/ does not answer like OctoPrint'
  end

  context 'without a URL' do
    let(:request) { described_class.new }

    it 'is invalid, without calling anything' do
      expect(request.save).to be(false)
      expect(request.errors.full_messages).to eq(["Url can't be blank"])
      expect(a_request(:any, /.*/)).not_to have_been_made
      expect { request.save! }.to raise_error(ActiveModel::ValidationError)
    end
  end
end
