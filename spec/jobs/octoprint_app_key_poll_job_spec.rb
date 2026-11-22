# frozen_string_literal: true

require 'rails_helper'
require 'support/app_key_request_helpers'

# OctoPrint is stubbed with WebMock: its appkeys plugin, and the API the new printer is identified and autofilled with
RSpec.describe OctoprintAppKeyPollJob, type: :job do
  include AppKeyRequestHelpers

  let(:api_key) { AppKeyRequestHelpers::API_KEY }
  let(:request) { create_request }
  let(:poll_url) { octoprint_url("plugin/appkeys/request/#{AppKeyRequestHelpers::APP_TOKEN}") }
  let(:poll) { stub_request(:get, poll_url) }
  let(:job) { described_class.new.tap { |job| allow(job).to receive(:sleep) } }

  # MockRedis has no pub/sub: what the spooler is sent
  before { redis.define_singleton_method(:publish) { |_channel, _message| 0 } }

  def json(status = 200, **body)
    { status:, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  def octoprint_profile(name)
    { id: '_default', name:, model: 'MK3S', default: true, current: true, heatedBed: true, heatedChamber: false,
      volume: { formFactor: 'rectangular', width: 250, depth: 210, height: 210 },
      extruder: { count: 1, nozzleDiameter: 0.4 } }
  end

  # The OctoPrint API, answering the new key only: identifyPrinter, then the autofill
  def stub_octoprint_api(profile_name: 'Prusa i3 MK3S')
    profile = octoprint_profile(profile_name)
    profiles = [profile.slice(:id, :name)]
    { 'api/connection' => { current: { state: 'Operational' }, options: { printerProfiles: profiles } },
      'api/version' => { api: '0.1', server: '1.11.2', text: 'OctoPrint 1.11.2' },
      'api/settings' => { webcam: { webcamEnabled: true } },
      'api/printerprofiles' => { profiles: { _default: profile } } }.each do |path, body|
      stub_request(:get, octoprint_url(path)).with(headers: { 'Authorization' => "Bearer #{api_key}" })
                                             .to_return(json(**body))
    end
  end

  def run_job
    subscribe_to_request(request.id)
    job.perform(request.id)
    deliver_events
  end

  shared_examples 'a request that never shows the API key' do
    it 'never pushes, broadcasts or logs the API key' do
      expect(pushes).to be_present
      expect(pushes.to_json).not_to include(api_key)
      expect(all_broadcasts.join).not_to include(api_key)
      expect(log.string).not_to include(api_key)
    end
  end

  context 'while the user has not decided (202)' do
    before do
      poll.to_return(json(202, message: 'Awaiting decision'))
      run_job
    end

    it 'polls a few times, a second apart, then enqueues itself again right away, keeping the request' do
      expect(poll).to have_been_made.times(described_class::POLLS_PER_RUN)
      expect(job).to have_received(:sleep).with(1).exactly(described_class::POLLS_PER_RUN - 1).times
      expect(described_class).to have_been_enqueued.with(request.id).exactly(:once)
      expect(enqueued_jobs.last).not_to have_key(:at)
      expect(Printer::AppKeyRequest.find(request.id)).to have_attributes(app_token: AppKeyRequestHelpers::APP_TOKEN)
      expect(pushes).to be_empty
    end
  end

  context 'when the user approves (200)' do
    before do
      poll.to_return(json(202, message: 'Awaiting decision'), json(api_key:))
      stub_octoprint_api
    end

    it 'adds the printer with the key and the name of its default profile, fills its specs, tells the spooler' do
      allow(redis).to receive(:publish).and_call_original
      expect { run_job }.to change(Printer, :count).by(1)

      expect(Printer.last).to have_attributes(name: 'Prusa i3 MK3S', backend: 'octoprint', uri: octoprint_url,
                                              secret: api_key, model: 'MK3S', build_volume_x: 250, webcam: true)
      expect(redis).to have_received(:publish)
        .with('printers', { command: 'add_printer', printer_id: Printer.last.id }.to_json)
    end

    it 'pushes ADDED with the new printer, and stops' do
      run_job
      printer = Printer.last

      expect(pushes).to eq([{ 'id' => request.id, 'address' => '192.168.1.57', 'state' => 'ADDED',
                              'approvalUrl' => request.approval_url, 'error' => nil,
                              'printer' => { 'id' => printer.id.to_s, 'name' => 'Prusa i3 MK3S',
                                             'uri' => octoprint_url } }])
      expect(Printer::AppKeyRequest.find(request.id)).to be_nil
      expect(described_class).not_to have_been_enqueued
    end

    it 'names the printer after its address when OctoPrint has no profile name' do
      stub_octoprint_api(profile_name: '')
      run_job

      expect(Printer.last.name).to eq('192.168.1.57')
    end

    it_behaves_like 'a request that never shows the API key' do
      before { run_job }
    end
  end

  context 'when the user denies it, or it expired in OctoPrint (404)' do
    before do
      poll.to_return(status: 404)
      run_job
    end

    it 'pushes DENIED, forgets the request and adds nothing' do
      expect(pushes).to eq([{ 'id' => request.id, 'address' => '192.168.1.57', 'state' => 'DENIED',
                              'approvalUrl' => request.approval_url, 'error' => nil, 'printer' => nil }])
      expect(Printer::AppKeyRequest.find(request.id)).to be_nil
      expect(Printer.count).to eq(0)
      expect(described_class).not_to have_been_enqueued
    end
  end

  context 'when OctoPrint is unreachable' do
    before do
      poll.to_timeout
      run_job
    end

    it 'pushes FAILED with the reason, and logs it' do
      expect(pushes).to contain_exactly(
        include('state' => 'FAILED', 'error' => 'Could not reach OctoPrint at http://192.168.1.57/', 'printer' => nil)
      )
      expect(Printer::AppKeyRequest.find(request.id)).to be_nil
      expect(log.string).to include("[OctoprintAppKeyPollJob] Request #{request.id} at http://192.168.1.57/ " \
                                    'failed: Printer::Backend::Unreachable')
    end
  end

  context 'when OctoPrint rejects the new key' do
    before do
      poll.to_return(json(api_key:))
      stub_request(:get, octoprint_url('api/connection')).to_return(json(403, error: 'Forbidden'))
      run_job
    end

    it 'pushes FAILED without the reason OctoPrint gave, and adds nothing' do
      expect(pushes).to contain_exactly(include('state' => 'FAILED', 'error' => 'OctoPrint rejected the new API key'))
      expect(Printer.count).to eq(0)
    end

    it_behaves_like 'a request that never shows the API key'
  end

  context 'when the request is cancelled while it polls' do
    before do
      poll.to_return(json(202, message: 'Awaiting decision'))
      allow(job).to receive(:sleep) do
        TentaclesSchema.execute(<<~GQL, variables: { id: request.id })
          mutation($id: ID!) { cancelPrinterAppKeyRequest(input: { id: $id }) { errors } }
        GQL
      end
      run_job
    end

    it 'stops polling without enqueuing itself again, leaving the CANCELLED push as the last word' do
      expect(poll).to have_been_made.once
      expect(described_class).not_to have_been_enqueued
      expect(pushes.pluck('state')).to eq(['CANCELLED'])
    end
  end

  context 'when the request is gone from Redis (expired or cancelled before the job ran)' do
    before do
      poll
      redis.del("printer_app_key_request_#{request.id}")
      run_job
    end

    it 'does nothing: no call to OctoPrint, no push, no new job' do
      expect(poll).not_to have_been_made
      expect(pushes).to be_empty
      expect(described_class).not_to have_been_enqueued
    end
  end
end
