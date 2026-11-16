# frozen_string_literal: true

require 'rails_helper'

module Mutations
  module Printers
    module AddPrinterSpec
      RSpec.describe AddPrinter, type: :request do
        let(:json) { response.parsed_body }
        let(:data) { json['data']['addPrinter'] }
        let(:redis) { instance_double(Redis, publish: 1, get: nil, set: 'OK') }
        let(:webcam) { Octoprint::Settings::Webcam.from_settings({ webcam: { webcam_enabled: true } }) }

        before do
          stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
          # The printer servers: an OctoPrint without printer profile, a PrusaLink XL
          allow(Octoprint::Settings).to receive(:webcam).and_return(webcam)
          allow(Octoprint::PrinterProfiles).to receive(:list).and_return(Octoprint::PrinterProfiles.new(profiles: {}))
          allow(Prusalink::Info).to receive(:get).and_return(Prusalink::Info.new(name: 'XL', nozzle_diameter: 0.6))
          allow(Prusalink::ServerVersion).to receive(:get).and_return(Prusalink::ServerVersion.new(firmware: '6.2.0'))
        end

        def add_printer(input)
          post '/graphql', params: { query:, variables: { input: } }
        end

        describe '.resolve' do
          context 'with an OctoPrint printer' do
            let(:input) { { name: 'Ender 3', uri: 'http://192.168.0.15', secret: '12345678' } }

            it 'adds a printer' do
              expect { add_printer(input) }.to change { Printer.count }.by(1)
            end

            it 'stores the credentials of an OctoPrint printer, the default backend' do
              add_printer(input)

              expect(Printer.last)
                .to have_attributes(name: 'Ender 3', backend: 'octoprint', uri: 'http://192.168.0.15',
                                    username: nil, secret: '12345678')
            end

            it 'adds an OctoPrint printer when the backend is null' do
              add_printer(input.merge(backend: nil))

              expect(data['errors']).to eq([])
              expect(Printer.last.backend).to eq('octoprint')
            end

            it 'returns the printer and no errors' do
              add_printer(input.merge(backend: 'OCTOPRINT'))
              printer = Printer.last

              expect(json['errors']).to be_nil
              expect(data).to eq(
                'printer' => { 'id' => printer.id.to_s, 'jobsCount' => 0, 'name' => 'Ender 3', 'backend' => 'OCTOPRINT',
                               'uri' => 'http://192.168.0.15', 'username' => nil },
                'errors' => []
              )
            end

            it 'tells the spooler, so that the printer gets a spool without a restart' do
              add_printer(input)

              expect(redis).to have_received(:publish)
                .with('printers', { command: 'add_printer', printer_id: Printer.last.id }.to_json).once
            end

            it 'fills the webcam from the OctoPrint settings' do
              add_printer(input)

              expect(Printer.last).to have_attributes(webcam: true, model: nil)
            end

            it 'adds the printer even when the spooler cannot be told' do
              allow(redis).to receive(:publish).and_raise(Redis::CannotConnectError)

              expect { add_printer(input) }.to change { Printer.count }.by(1)
              expect(data['errors']).to eq([])
            end
          end

          context 'with a PrusaLink printer' do
            let(:input) do
              { backend: 'PRUSALINK', name: 'Prusa MK4', uri: 'http://prusa-mk4.local', username: 'maker',
                secret: 'printer-password' }
            end

            it 'stores its credentials' do
              add_printer(input)

              expect(Printer.last)
                .to have_attributes(name: 'Prusa MK4', backend: 'prusalink', uri: 'http://prusa-mk4.local',
                                    username: 'maker', secret: 'printer-password')
            end

            it 'returns the printer, never its password' do
              add_printer(input)

              expect(json['errors']).to be_nil
              expect(data['errors']).to eq([])
              expect(data['printer']).to include('name' => 'Prusa MK4', 'backend' => 'PRUSALINK',
                                                 'uri' => 'http://prusa-mk4.local', 'username' => 'maker')
              expect(response.body).not_to include('printer-password')
            end

            it 'fills its specs with what PrusaLink reports' do
              add_printer(input)

              expect(Printer.last).to have_attributes(firmware: 'prusa_firmware', firmware_version: '6.2.0',
                                                      nozzle_diameter: 0.6, name: 'Prusa MK4')
            end

            it 'adds the printer even when its specs cannot be read' do
              allow(Prusalink::Info).to receive(:get).and_raise(Prusalink::Exceptions::AuthenticationError, '[401]')

              expect { add_printer(input) }.to change { Printer.count }.by(1)
              expect(data['errors']).to eq([])
              expect(Printer.last).to have_attributes(firmware: nil, nozzle_diameter: nil)
            end

            it 'adds the printer even when it is unreachable' do
              allow(Prusalink::Info).to receive(:get).and_raise(Prusalink::Exceptions::ConnectionError, 'timeout')

              expect { add_printer(input) }.to change { Printer.count }.by(1)
              expect(data['errors']).to eq([])
            end

            it 'stores a blank username as nil (the default username)' do
              add_printer(input.merge(username: ''))

              expect(Printer.last.username).to be_nil
            end
          end

          context 'with the removed octoprintUri and octoprintKey' do
            let(:input) { { name: 'Ender 3', octoprintUri: 'http://192.168.0.15', octoprintKey: '12345678' } }

            it 'refuses them without adding a printer' do
              expect { add_printer(input) }.not_to(change { Printer.count })
              expect(json['errors'].pluck('message').join).to include('octoprintUri', 'octoprintKey')
            end
          end

          context 'with invalid arguments' do
            let(:input) { { backend: 'PRUSALINK', name: '', uri: '', secret: '' } }

            it 'does not add a printer nor tell the spooler' do
              expect { add_printer(input) }.not_to(change { Printer.count })
              expect(redis).not_to have_received(:publish)
            end

            it 'returns a nil printer and the validation errors' do
              add_printer(input)

              expect(json['errors']).to be_nil
              expect(data).to eq(
                'printer' => nil,
                'errors' => ["Name can't be blank", "URL can't be blank", "API key or password can't be blank"]
              )
            end
          end

          context 'without a URI' do
            it 'returns the error instead of a silent nil printer' do
              add_printer({ name: 'Ender 3', secret: '12345678' })

              expect(data).to eq('printer' => nil, 'errors' => ["URL can't be blank"])
            end
          end
        end

        def query
          <<~GQL
            mutation addPrinter($input: AddPrinterInput!) {
              addPrinter(input: $input) {
                printer {
                  id
                  jobsCount
                  name
                  backend
                  uri
                  username
                }
                errors
              }
            }
          GQL
        end
      end
    end
  end
end
