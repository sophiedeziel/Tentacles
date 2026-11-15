# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query printers { status }', type: :request do
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
            stateFamily stateText errorText fileName progress printTimeLeft
            hotend { actual target }
            bed { actual target }
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
      PrinterStatusStore.write(
        PrinterStatus.new(
          printer_id: printer.id,
          state_family: PrinterStateFamily::Printing,
          state_text: 'Printing from SD',
          file_name: "part_#{printer.id}.gcode",
          progress: 42.5,
          print_time_left: 3600,
          hotend: PrinterStatus::Temperature.new(actual: 210.3, target: 210.0),
          bed: PrinterStatus::Temperature.new(actual: 59.8, target: 60.0),
          camera: PrinterStatus::Camera.new(enabled: true, stream_url: 'http://octopi.local/webcam/?action=stream'),
          last_seen_at:,
          updated_at:
        )
      )
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
        'errorText' => nil,
        'fileName' => "part_#{printer.id}.gcode",
        'progress' => 42.5,
        'printTimeLeft' => 3600,
        'hotend' => { 'actual' => 210.3, 'target' => 210.0 },
        'bed' => { 'actual' => 59.8, 'target' => 60.0 },
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
        'errorText' => nil,
        'fileName' => nil,
        'progress' => nil,
        'printTimeLeft' => nil,
        'hotend' => nil,
        'bed' => nil,
        'camera' => { 'enabled' => false, 'streamUrl' => nil },
        'lastSeenAt' => printer.reload.last_seen_at.utc.iso8601,
        'updatedAt' => nil
      )
    end
  end

  it 'returns OFFLINE / Unknown for a printer without snapshot nor last_seen_at' do
    printer = without_snapshot.first
    printer.update!(last_seen_at: nil)

    post '/graphql', params: { query: }

    expect(statuses[printer.id]).to include('stateFamily' => 'OFFLINE', 'stateText' => 'Unknown', 'lastSeenAt' => nil)
  end

  it 'falls back to Unknown when a snapshot is unreadable' do
    printer = with_snapshot.first
    redis.set(PrinterStatusStore.key(printer.id), 'not json')

    post '/graphql', params: { query: }

    expect(json['errors']).to be_nil
    expect(statuses[printer.id]).to include('stateFamily' => 'OFFLINE', 'stateText' => 'Unknown')
  end

  it 'falls back to Unknown for snapshots written before a prop was added, or null' do
    redis.set(PrinterStatusStore.key(with_snapshot.first.id), { printer_id: with_snapshot.first.id }.to_json)
    redis.set(PrinterStatusStore.key(with_snapshot.second.id), 'null')

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

  it 'serializes every state family' do
    PrinterStateFamily.values.zip(printers).each do |family, printer|
      PrinterStatusStore.write(PrinterStatus.new(printer_id: printer.id, state_family: family, state_text: 'x'))
    end

    post '/graphql', params: { query: }

    expect(PrinterStateFamily.values.zip(printers).map { |_family, printer| statuses[printer.id]['stateFamily'] })
      .to eq(%w[PRINTING PAUSED CANCELLING OPERATIONAL CONNECTING ERROR OFFLINE])
  end
end
