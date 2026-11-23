# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query printers { status }', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:redis) { MockRedis.new }
  let!(:printers) { create_list(:printer, 20) }
  let(:with_snapshot) { printers.first(15) }
  let(:without_snapshot) { printers.last(5) }
  let(:last_seen_at) { Time.utc(2026, 11, 15, 4, 55, 0) }
  let(:updated_at) { Time.utc(2026, 11, 15, 5, 0, 0, 123_000) }

  let(:query) do
    <<~GQL
      query {
        printers {
          id
          status {
            stateFamily stateText serverReachable errorText fileName progress printTimeLeft
            hotend { actual target unit }
            bed { actual target unit }
            camera { enabled streamUrl }
            lastSeenAt updatedAt
          }
        }
      }
    GQL
  end

  let(:json) { response.parsed_body }
  let(:statuses) { json['data']['printers'].to_h { |printer| [printer['id'].to_i, printer['status']] } }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })

    with_snapshot.each do |printer|
      Printer::Status.new(
        printer_id: printer.id,
        state_family: Printer::StateFamily::Printing,
        state_text: 'Printing from SD',
        file_name: "part_#{printer.id}.gcode",
        progress: 42.5,
        print_time_left: 3600,
        hotend: Printer::Status::Temperature.new(actual: 210.3, target: 210.0),
        bed: Printer::Status::Temperature.new(actual: 59.8, target: 60.0),
        camera: Printer::Status::Camera.new(enabled: true, stream_url: 'http://octopi.local/webcam/?action=stream'),
        last_seen_at:,
        updated_at:
      ).save!
    end
    without_snapshot.each { |printer| printer.update!(last_seen_at: 1.hour.ago.round) }
  end

  it 'reads every status with a single Redis MGET, never calling OctoPrint' do
    expect(redis).to receive(:mget).once.and_call_original
    expect(redis).not_to receive(:get)
    expect(Octoprint::Client).not_to receive(:new)
    expect(Octoprint::Job).not_to receive(:get)
    expect(Octoprint::Printer).not_to receive(:get)

    post '/graphql', params: { query: }

    expect(json['errors']).to be_nil
    expect(json['data']['printers'].size).to eq(20)
  end

  it 'serializes the snapshots' do
    post '/graphql', params: { query: }

    with_snapshot.each do |printer|
      expect(statuses[printer.id]).to eq(
        'stateFamily' => 'PRINTING',
        'stateText' => 'Printing from SD',
        'serverReachable' => true,
        'errorText' => nil,
        'fileName' => "part_#{printer.id}.gcode",
        'progress' => 43,
        'printTimeLeft' => 'PT1H',
        'hotend' => { 'actual' => 210.0, 'target' => 210.0, 'unit' => 'CELSIUS' },
        'bed' => { 'actual' => 60.0, 'target' => 60.0, 'unit' => 'CELSIUS' },
        'camera' => { 'enabled' => true, 'streamUrl' => 'http://octopi.local/webcam/?action=stream' },
        'lastSeenAt' => '2026-11-15T04:55:00Z',
        'updatedAt' => '2026-11-15T05:00:00Z'
      )
    end
  end

  it 'returns OFFLINE / Unknown with lastSeenAt from the printer for printers without a snapshot' do
    post '/graphql', params: { query: }

    without_snapshot.each do |printer|
      expect(statuses[printer.id]).to eq(
        'stateFamily' => 'OFFLINE',
        'stateText' => 'Unknown',
        'serverReachable' => false,
        'errorText' => nil,
        'fileName' => nil,
        'progress' => nil,
        'printTimeLeft' => nil,
        'hotend' => nil,
        'bed' => nil,
        'camera' => { 'enabled' => false, 'streamUrl' => nil },
        'lastSeenAt' => printer.reload.last_seen_at.utc.iso8601,
        'updatedAt' => printer.last_seen_at.utc.iso8601
      )
    end
  end

  it 'falls back to Unknown for snapshots written before a prop was added, or null' do
    redis.set(Printer::Status.key(with_snapshot.first.id), { printer_id: with_snapshot.first.id }.to_json)
    redis.set(Printer::Status.key(with_snapshot.second.id), 'null')

    post '/graphql', params: { query: }

    expect(json['errors']).to be_nil
    expect(statuses.values_at(with_snapshot.first.id,
                              with_snapshot.second.id).pluck('stateText')).to eq %w[Unknown Unknown]
  end

  it 'returns Unknown for every printer instead of failing when Redis is down' do
    allow(redis).to receive(:mget).and_raise(Redis::CannotConnectError)

    post '/graphql', params: { query: }

    expect(json['errors']).to be_nil
    expect(statuses.values.pluck('stateText').uniq).to eq ['Unknown']
  end

  describe 'value formats' do
    let(:printer) { with_snapshot.first }

    def status_with(**attributes)
      Printer::Status.new(printer_id: printer.id, state_family: Printer::StateFamily::Printing, state_text: 'Printing',
                          **attributes).save!
      current_status
    end

    # Several requests per example: not the memoized json
    def current_status
      post '/graphql', params: { query: }
      body = response.parsed_body
      expect(body['errors']).to be_nil
      body.dig('data', 'printers').to_h { |each| [each['id'], each['status']] }.fetch(printer.id.to_s)
    end

    it 'rounds progress to an integer from 0 to 100' do
      expect(status_with(progress: 99.6)['progress']).to eq(100)
      expect(status_with(progress: 0.4)['progress']).to eq(0)
      expect(status_with(progress: 100.2)['progress']).to eq(100)
    end

    it 'returns printTimeLeft as an ISO 8601 duration rounded to 1 minute' do
      expect(status_with(print_time_left: 3119)['printTimeLeft']).to eq('PT52M')
      expect(status_with(print_time_left: 4330)['printTimeLeft']).to eq('PT1H12M')
      expect(status_with(print_time_left: 20)['printTimeLeft']).to eq('PT0S')
      expect(status_with(print_time_left: -5)['printTimeLeft']).to eq('PT0S')
    end

    it 'returns a target of 0 when OctoPrint has none' do
      hotend = status_with(hotend: Printer::Status::Temperature.new(actual: 24.6, target: nil))['hotend']

      expect(hotend).to eq('actual' => 25.0, 'target' => 0.0, 'unit' => 'CELSIUS')
    end

    it 'returns a null temperature without a current reading' do
      expect(status_with(bed: Printer::Status::Temperature.new(actual: nil, target: 60.0))['bed']).to be_nil
    end

    it 'always has an updatedAt, falling back to the time of the query for printers never seen' do
      freeze_time do
        printer = without_snapshot.first
        printer.update!(last_seen_at: nil)

        post '/graphql', params: { query: }

        expect(statuses[printer.id]['updatedAt']).to eq(Time.current.utc.iso8601)
      end
    end
  end
end
