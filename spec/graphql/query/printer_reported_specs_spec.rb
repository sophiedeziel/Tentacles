# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Types::Printer, 'reportedSpecs', type: :request do
  let(:printer) { create(:printer, :prusalink, model: 'Custom MK4') }
  let(:redis) { MockRedis.new }
  let(:query) do
    <<~GQL
      query printer($id: ID!) {
        printer(id: $id) {
          specs { model }
          reportedSpecs {
            brand model firmware firmwareDisplayName firmwareVersion nozzleDiameter webcam materials
            buildVolume { __typename }
          }
        }
      }
    GQL
  end
  def json = response.parsed_body
  def reported = json.dig('data', 'printer', 'reportedSpecs')

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(Prusalink::Info).to receive(:get).and_return(Prusalink::Info.new(name: 'XL', nozzle_diameter: 0.6))
    allow(Prusalink::ServerVersion).to receive(:get)
      .and_return(Prusalink::ServerVersion.new(printer: 'XL', firmware: '6.2.0+8899'))
  end

  def query_printer
    post '/graphql', params: { query:, variables: { id: printer.id } }
    expect(json['errors']).to be_nil
  end

  it "returns what the printer's server reports, next to the saved specs" do
    query_printer

    expect(json.dig('data', 'printer', 'specs')).to eq('model' => 'Custom MK4')
    expect(reported).to eq(
      'brand' => nil, 'model' => 'XL', 'firmware' => 'PRUSA_FIRMWARE', 'firmwareDisplayName' => 'prusa_firmware',
      'firmwareVersion' => '6.2.0+8899', 'nozzleDiameter' => 0.6, 'webcam' => nil, 'materials' => [],
      'buildVolume' => nil
    )
  end

  it 'is null, without calling the server, while the printer is flagged disconnected' do
    PrinterApiCache.set_disconnected(printer.id)

    query_printer

    expect(reported).to be_nil
    expect(Prusalink::Info).not_to have_received(:get)
  end

  it 'is null when the printer is unreachable' do
    allow(Prusalink::Info).to receive(:get).and_raise(Prusalink::Exceptions::ConnectionError, 'timeout')

    query_printer

    expect(reported).to be_nil
  end

  it 'is null when the server refuses the credentials' do
    allow(Prusalink::Info).to receive(:get).and_raise(Prusalink::Exceptions::AuthenticationError, '[401]')

    query_printer

    expect(reported).to be_nil
  end
end
