# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Upload, :vcr do
  let(:printer) { build(:printer) }
  let(:file_path) { 'spec/fixture_files/test.gcode' }

  subject(:upload) { described_class.new(printer:, path: file_path) }

  it 'does not print by default' do
    expect(upload.print).to be false
  end

  it 'needs a printer and a path' do
    empty = described_class.new

    expect(empty).to be_invalid
    expect(empty.errors.full_messages).to contain_exactly("Printer can't be blank", "Path can't be blank")
  end

  it 'uploads the file through the adapter, and starts the print when asked to' do
    allow(printer.api).to receive(:upload)

    described_class.new(printer:, path: file_path, print: true).save!

    expect(printer.api).to have_received(:upload).with(file_path, print: true)
  end

  it 'uploads the file', vcr: { cassette_name: 'Printer/upload/1_8_1' } do
    expect { upload.save! }.not_to raise_error
  end

  it 'uses a client with long timeouts for large files', vcr: { cassette_name: 'Printer/upload/1_8_1' } do
    allow(Octoprint::Client).to receive(:new).and_call_original
    upload.save!
    expect(Octoprint::Client).to have_received(:new)
      .with(hash_including(host: printer.uri, api_key: printer.secret, open_timeout: 5, timeout: 120))
  end

  [Octoprint::Exceptions::ConnectionError, Octoprint::Exceptions::TimeoutError].each do |error_class|
    context "when the upload fails with #{error_class.name.demodulize}" do
      let(:printer) { create(:printer) }
      let(:redis) { MockRedis.new }

      before do
        stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
        allow(Octoprint::Files).to receive(:upload).and_raise(error_class, 'execution expired')
        allow(Printer::Disconnection).to receive(:create!)
      end

      it 'raises the error' do
        expect { upload.save! }.to raise_error(Printer::Backend::Unreachable, 'execution expired')
      end

      it 'does not mark the printer as disconnected' do
        expect { upload.save! }.to raise_error(Printer::Backend::Unreachable)
        expect(Printer::Disconnection).not_to have_received(:create!)
        expect(Printer::Disconnection.exists?(printer_id: printer.id)).to be false
      end
    end
  end
end
