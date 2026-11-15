# frozen_string_literal: true

require 'rails_helper'

# The gems are stubbed: nothing reaches the network
RSpec.describe 'Query identifyPrinter', type: :request do
  let(:secret) { 's3cr3t-passw0rd' }
  let(:variables) { { backend:, uri: 'http://192.168.0.15/', secret: } }
  let(:query) do
    <<~GQL
      query identifyPrinter($backend: PrinterBackend!, $uri: String!, $username: String, $secret: String!) {
        identifyPrinter(backend: $backend, uri: $uri, username: $username, secret: $secret) {
          name
          version
        }
      }
    GQL
  end
  let(:json) { response.parsed_body }
  let(:error) { json['errors']&.first }

  def identify
    post '/graphql', params: { query:, variables: }
  end

  shared_examples 'a failed identification' do |code, message|
    let(:warnings) { [] }

    before do
      allow(Rails.logger).to receive(:warn).and_wrap_original do |original, *args|
        warnings.concat(args)
        original.call(*args)
      end
      identify
    end

    it "returns a #{code} error" do
      expect(json['data']).to be_nil
      expect(error['message']).to match(message)
      expect(error['extensions']).to eq('code' => code)
      expect(error['path']).to eq(['identifyPrinter'])
    end

    it 'never returns nor logs the secret' do
      expect(response.body).not_to include(secret)
      expect(warnings).to include(/\A\[identifyPrinter\]/)
      expect(warnings.join).not_to include(secret)
    end

    it 'saves nothing' do
      expect(Printer.count).to eq(0)
    end
  end

  context 'with an OctoPrint printer' do
    let(:backend) { 'OCTOPRINT' }

    before do
      allow(Octoprint::ServerVersion).to receive(:get)
        .and_return(Octoprint::ServerVersion.new(api: '0.1', server: '1.11.2', text: 'OctoPrint 1.11.2'))
      allow(Octoprint::Connection).to receive(:get).and_return(
        Octoprint::Connection.new(current: { state: 'Operational' },
                                  options: { printer_profiles: [{ id: '_default', name: 'Ender 3' }] })
      )
    end

    it "returns the default printer profile's name and OctoPrint's version" do
      identify

      expect(json['errors']).to be_nil
      expect(json['data']['identifyPrinter']).to eq('name' => 'Ender 3', 'version' => 'OctoPrint 1.11.2')
    end

    it 'calls OctoPrint with the given URL and API key' do
      allow(Octoprint::Client).to receive(:new).and_call_original

      identify

      expect(Octoprint::Client).to have_received(:new)
        .with(hash_including(host: 'http://192.168.0.15/', api_key: secret))
    end

    context 'when OctoPrint rejects the API key' do
      before do
        allow(Octoprint::Connection).to receive(:get)
          .and_raise(Octoprint::Exceptions::AuthenticationError, "Invalid API key #{secret}")
      end

      it_behaves_like 'a failed identification', 'UNAUTHORIZED', 'OctoPrint rejected the API key'
    end

    context 'when OctoPrint is unreachable' do
      before do
        allow(Octoprint::Connection).to receive(:get)
          .and_raise(Octoprint::Exceptions::ConnectionError, "Failed to open TCP connection (key #{secret})")
      end

      it_behaves_like 'a failed identification', 'UNREACHABLE',
                      %r{\ACould not reach OctoPrint at http://192\.168\.0\.15/: .*\[FILTERED\]}
    end

    context 'when OctoPrint times out' do
      before { allow(Octoprint::Connection).to receive(:get).and_raise(Octoprint::Exceptions::TimeoutError, 'expired') }

      it_behaves_like 'a failed identification', 'UNREACHABLE', 'Could not reach OctoPrint'
    end

    context 'when the URL does not answer like OctoPrint' do
      before { allow(Octoprint::Connection).to receive(:get).and_raise(JSON::ParserError, "unexpected '<html>'") }

      it_behaves_like 'a failed identification', 'PRINTER_ERROR',
                      'http://192.168.0.15/ does not answer like OctoPrint'
    end
  end

  context 'with a PrusaLink printer' do
    let(:backend) { 'PRUSALINK' }

    before do
      allow(Prusalink::Info).to receive(:get).and_return(Prusalink::Info.deserialize({ name: 'Prusa MK4' }))
      allow(Prusalink::ServerVersion).to receive(:get)
        .and_return(Prusalink::ServerVersion.deserialize({ version: '2.1.2', firmware: '6.1.3' }))
    end

    it "returns the printer's name and PrusaLink's version" do
      identify

      expect(json['errors']).to be_nil
      expect(json['data']['identifyPrinter'])
        .to eq('name' => 'Prusa MK4', 'version' => 'PrusaLink 2.1.2 (firmware 6.1.3)')
    end

    it 'calls PrusaLink with the given URL, username and password' do
      allow(Prusalink::Client).to receive(:new).and_call_original
      variables[:username] = 'operator'

      identify

      expect(Prusalink::Client).to have_received(:new)
        .with(hash_including(host: 'http://192.168.0.15/', username: 'operator', password: secret))
    end

    it 'uses the default username when none is given' do
      allow(Prusalink::Client).to receive(:new).and_call_original

      identify

      expect(Prusalink::Client).to have_received(:new).with(hash_including(username: 'maker'))
    end

    it 'falls back to the host when the printer has no name' do
      allow(Prusalink::Info).to receive(:get).and_return(Prusalink::Info.deserialize({}))

      identify

      expect(json['data']['identifyPrinter']['name']).to eq('192.168.0.15')
    end

    context 'when PrusaLink rejects the password' do
      before do
        allow(Prusalink::Info).to receive(:get)
          .and_raise(Prusalink::Exceptions::AuthenticationError, "401 Unauthorized #{secret}")
      end

      it_behaves_like 'a failed identification', 'UNAUTHORIZED', 'PrusaLink rejected the username or password'
    end

    context 'when PrusaLink is unreachable' do
      before do
        allow(Prusalink::Info).to receive(:get)
          .and_raise(Prusalink::Exceptions::ConnectionError, "Failed to open TCP connection (#{secret})")
      end

      it_behaves_like 'a failed identification', 'UNREACHABLE',
                      %r{\ACould not reach PrusaLink at http://192\.168\.0\.15/: .*\[FILTERED\]}
    end

    context 'when PrusaLink times out' do
      before { allow(Prusalink::Info).to receive(:get).and_raise(Prusalink::Exceptions::TimeoutError, 'expired') }

      it_behaves_like 'a failed identification', 'UNREACHABLE', 'Could not reach PrusaLink'
    end

    context 'when PrusaLink returns another error' do
      before do
        allow(Prusalink::Info).to receive(:get).and_raise(Prusalink::Exceptions::ConflictError, "busy #{secret}")
      end

      it_behaves_like 'a failed identification', 'PRINTER_ERROR', /\APrusaLink returned an error: busy \[FILTERED\]\z/
    end

    context "when PrusaLink's answer is a whole page" do
      before do
        page = "[404] <html>\n<head><title>Not Found</title></head>\n<body>#{'x' * 500} #{secret}</body>\n</html>"
        allow(Prusalink::Info).to receive(:get).and_raise(Prusalink::Exceptions::NotFoundError, page)
      end

      it_behaves_like 'a failed identification', 'PRINTER_ERROR', /\APrusaLink returned an error: \[404\] <html>\z/
    end

    context 'when the secret is cut by the length limit' do
      before do
        allow(Prusalink::Info).to receive(:get)
          .and_raise(Prusalink::Exceptions::ConflictError, "#{'x' * 110}#{secret}")
      end

      it_behaves_like 'a failed identification', 'PRINTER_ERROR', /\[FILTERED\]/
    end

    context 'without a password' do
      let(:secret) { '' }

      before { identify }

      it 'returns a PRINTER_ERROR without calling PrusaLink' do
        expect(error['message']).to eq('Enter the URL and the password')
        expect(error['extensions']).to eq('code' => 'PRINTER_ERROR')
        expect(Prusalink::Info).not_to have_received(:get)
      end
    end
  end
end
