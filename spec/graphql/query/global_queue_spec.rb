# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query globalQueue', type: :request do
  let(:json) { response.parsed_body }
  # The printers' snapshots, by printer id: Printer::Status.where reads them from here
  let(:statuses) { {} }

  before do
    allow(PrintQueue).to receive(:enabled?).and_return(true)
    allow(Printer::Status).to receive(:where) do |printer_id:|
      Array(printer_id).filter_map { |id| statuses[id] }
    end
  end

  def run(query, variables = {})
    post '/graphql', params: { query:, variables: variables.to_json }
    body = response.parsed_body
    expect(body['errors']).to be_nil
    body.dig('data', 'globalQueue')
  end

  # The SQL queries the block runs. With cached: true, the ones the query cache answers count too: whether a load is
  # answered from the cache depends on the ids it asks for, not on the number of rows
  def sql_queries(cached: false, &)
    queries = []
    counter = lambda do |_name, _start, _finish, _id, payload|
      next if %w[SCHEMA TRANSACTION].include?(payload[:name]) || (payload[:cached] && !cached)

      queries << payload[:sql]
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    queries
  end

  # A printer with PLA Black loaded, in this state family
  def printer(family = Printer::StateFamily::Operational, name: 'Prusa MK4', **attributes)
    create(:printer, name:, **attributes).tap do |printer|
      create(:printer_loaded_filament, printer:, material: 'PLA', colour: 'Black')
      statuses[printer.id] = Printer::Status.new(printer_id: printer.id, state_family: family,
                                                 state_text: family.serialize.capitalize)
    end
  end

  # An entry of a PLA file whose summary is read
  def entry(**attributes)
    create(:print_job, **attributes).tap do |job|
      create(:gcode_summary, :ready, :with_tools, item: job.item, materials: ['PLA'])
    end
  end

  def copy(entry, printer, status, **attributes)
    create(:printer_job, :copy, print_job: entry, printer:, status:, **attributes)
  end

  def id(record) = record.id.to_s

  it 'is null while the global queue is off' do
    allow(PrintQueue).to receive(:enabled?).and_return(false)

    post '/graphql', params: { query: '{ globalQueue { dispatchPaused } }' }

    expect(json).to eq('data' => { 'globalQueue' => nil })
  end

  describe 'dispatchPaused' do
    it 'is whether dispatch is paused' do
      expect(run('{ globalQueue { dispatchPaused } }')).to eq('dispatchPaused' => false)

      PrintQueue::Setting.current.update!(dispatch_paused: true)

      expect(run('{ globalQueue { dispatchPaused } }')).to eq('dispatchPaused' => true)
    end

    it 'reads only the setting' do
      PrintQueue::Setting.current

      queries = sql_queries { run('{ globalQueue { dispatchPaused } }') }

      expect(queries.size).to eq 1
    end
  end

  describe 'printersToClear and availablePrinters' do
    it 'lists the printers whose bed needs clearing, and the printers free for a job' do
      on_bed = printer(name: 'Voron')
      copy(entry, on_bed, 'completed', started_at: 2.hours.ago, finished_at: 1.hour.ago)
      free = printer(name: 'Prusa XL')
      printer(name: 'Off', takes_jobs: false)
      printer(Printer::StateFamily::Printing, name: 'Busy')

      queue = run('{ globalQueue { printersToClear { id name } availablePrinters { id name } } }')

      expect(queue).to eq('printersToClear' => [{ 'id' => id(on_bed), 'name' => 'Voron' }],
                          'availablePrinters' => [{ 'id' => id(free), 'name' => 'Prusa XL' }])
    end
  end

  describe 'offlinePrinters' do
    it 'lists the printers that take jobs but are offline, connecting or in error' do
      offline = printer(Printer::StateFamily::Offline, name: 'Prusa Mini')
      error = printer(Printer::StateFamily::Error, name: 'Ender')
      no_status = create(:printer, name: 'Never seen')
      printer(Printer::StateFamily::Offline, name: 'Off', takes_jobs: false)
      printer(name: 'Online')

      expect(run('{ globalQueue { offlinePrinters { id } } }')['offlinePrinters'].pluck('id'))
        .to eq [id(offline), id(error), id(no_status)]
    end
  end

  describe 'Printer.takesNext' do
    let(:query) do
      '{ globalQueue { printersToClear { name takesNext { id } } availablePrinters { name takesNext { id } } } }'
    end

    it 'is the print job each printer takes next, as if dispatch were running' do
      on_bed = printer(name: 'Ender 3 V2')
      copy(entry, on_bed, 'completed', started_at: 2.hours.ago, finished_at: 1.hour.ago)
      printer(name: 'Prusa XL')
      first = entry(position: 1)
      second = entry(position: 2)
      PrintQueue::Setting.current.update!(dispatch_paused: true)

      expect(run(query)).to eq(
        'printersToClear' => [{ 'name' => 'Ender 3 V2', 'takesNext' => { 'id' => id(second) } }],
        'availablePrinters' => [{ 'name' => 'Prusa XL', 'takesNext' => { 'id' => id(first) } }]
      )
    end

    it 'is null while the global queue is off' do
      mk4 = printer
      entry
      allow(PrintQueue).to receive(:enabled?).and_return(false)

      post '/graphql', params: { query: "{ printer(id: #{mk4.id}) { takesNext { id } } }" }

      expect(json.dig('data', 'printer')).to eq('takesNext' => nil)
    end
  end

  describe 'printing and finished' do
    let(:query) do
      <<~GRAPHQL
        query($first: Int!) {
          globalQueue {
            printing { id copyNumber status progress startedAt result printer { name } printJob { id } }
            finished(first: $first) {
              id status result finishedAt bedClearedAt bedClearedBy printJob { file { filename } }
            }
          }
        }
      GRAPHQL
    end

    it 'lists the copies handed out and not ended, then the ended ones, the last ended first' do
      mk4 = printer
      queued = entry(copies: 5)
      started = 10.minutes.ago.change(usec: 0)
      active = copy(queued, mk4, 'active', progress: 42.5, started_at: started, created_at: 20.minutes.ago)
      enqueued = copy(queued, mk4, 'enqueued', created_at: 1.minute.ago)
      failed = copy(queued, mk4, 'error', started_at: 3.hours.ago, finished_at: 2.hours.ago,
                                          bed_cleared_at: 1.hour.ago, bed_cleared_by: 'person')
      done = copy(queued, mk4, 'completed', started_at: 2.hours.ago, finished_at: 1.hour.ago.change(usec: 0))
      create(:printer_job, printer: mk4, status: 'active') # an old-style job: not a copy

      queue = run(query, first: 10)

      expect(queue['printing']).to eq [
        { 'id' => id(active), 'copyNumber' => 1, 'status' => 'ACTIVE', 'progress' => 42.5,
          'startedAt' => started.iso8601, 'result' => nil, 'printer' => { 'name' => 'Prusa MK4' },
          'printJob' => { 'id' => id(queued) } },
        { 'id' => id(enqueued), 'copyNumber' => 2, 'status' => 'ENQUEUED', 'progress' => 0.0, 'startedAt' => nil,
          'result' => nil, 'printer' => { 'name' => 'Prusa MK4' }, 'printJob' => { 'id' => id(queued) } }
      ]
      expect(queue['finished']).to eq [
        { 'id' => id(done), 'status' => 'COMPLETED', 'result' => 'COMPLETED', 'finishedAt' => done.finished_at.iso8601,
          'bedClearedAt' => nil, 'bedClearedBy' => nil, 'printJob' => { 'file' => { 'filename' => 'test.gcode' } } },
        { 'id' => id(failed), 'status' => 'ERROR', 'result' => 'FAILED', 'finishedAt' => failed.finished_at.iso8601,
          'bedClearedAt' => failed.bed_cleared_at.iso8601, 'bedClearedBy' => 'PERSON',
          'printJob' => { 'file' => { 'filename' => 'test.gcode' } } }
      ]
    end

    it 'returns the first finished copies only, and refuses more than 50' do
      mk4 = printer
      queued = entry(copies: 3)
      3.times { |index| copy(queued, mk4, 'cancelled', finished_at: (index + 1).hours.ago) }

      expect(run(query, first: 2)['finished'].pluck('result')).to eq %w[CANCELLED CANCELLED]

      post '/graphql', params: { query:, variables: { first: 51 }.to_json }
      expect(response.parsed_body['errors'].pluck('message')).to eq ['first must be within 0..50']
    end
  end

  describe 'waiting' do
    let(:query) do
      <<~GRAPHQL
        {
          globalQueue {
            waiting {
              id position copies held samePrinter allCapable copiesLeftToStart boundPrinter { name }
              file { filename }
              needs { pending known colour filaments { tool material colour } footprint { width depth } toolCount }
              eligiblePrinters { name }
              whatHappensNext { kind printer { name } jobsAhead dispatchPaused }
              prints { copyNumber status }
            }
          }
        }
      GRAPHQL
    end

    it 'lists the print jobs with copies left to start, in queue order' do
      mk4 = printer
      second = entry(position: 2, colour: 'Black')
      first = entry(position: 1, copies: 3)
      copy(first, mk4, 'completed', started_at: 2.hours.ago, finished_at: 1.hour.ago, bed_cleared_at: 1.minute.ago)
      all_printing = entry(position: 0)
      copy(all_printing, mk4, 'enqueued')

      waiting = run(query)['waiting']

      expect(waiting.pluck('id')).to eq [id(first), id(second)]
      expect(waiting.first).to eq(
        'id' => id(first), 'position' => 1, 'copies' => 3, 'held' => false, 'samePrinter' => false,
        'allCapable' => true, 'copiesLeftToStart' => 2, 'boundPrinter' => nil, 'file' => { 'filename' => 'test.gcode' },
        'needs' => { 'pending' => false, 'known' => true, 'colour' => nil,
                     'filaments' => [{ 'tool' => 0, 'material' => 'PLA', 'colour' => nil }],
                     'footprint' => { 'width' => 123.09, 'depth' => 130.0 }, 'toolCount' => 1 },
        'eligiblePrinters' => [{ 'name' => 'Prusa MK4' }],
        'whatHappensNext' => { 'kind' => 'AFTER_CURRENT_PRINT', 'printer' => { 'name' => 'Prusa MK4' },
                               'jobsAhead' => 0, 'dispatchPaused' => false },
        'prints' => [{ 'copyNumber' => 1, 'status' => 'COMPLETED' }]
      )
      expect(waiting.last['needs']['filaments']).to eq [{ 'tool' => 0, 'material' => 'PLA', 'colour' => 'Black' }]
    end

    it 'shows a pending summary as pending, without a footprint' do
      pending = create(:print_job, colour: 'Red')
      create(:gcode_summary, item: pending.item)

      expect(run(query)['waiting'].sole['needs']).to eq(
        'pending' => true, 'known' => false, 'colour' => 'Red', 'filaments' => [], 'footprint' => nil,
        'toolCount' => nil
      )
    end
  end

  describe 'the number of SQL queries' do
    let(:query) do
      <<~GRAPHQL
        {
          globalQueue {
            dispatchPaused
            printersToClear { id name takesNext { id file { filename } } }
            availablePrinters { id name takesNext { id } }
            offlinePrinters { id name }
            printing { id status printer { name } printJob { id file { filename } whatHappensNext { kind } } }
            waiting {
              id allCapable copiesLeftToStart boundPrinter { name } file { filename }
              needs { pending filaments { material } footprint { width } }
              eligiblePrinters { name takesNext { id } }
              whatHappensNext { kind printer { name } jobsAhead dispatchPaused }
              prints { id status printer { name } }
            }
            finished(first: 50) { id result printer { name } printJob { file { filename } copiesLeftToStart } }
          }
        }
      GRAPHQL
    end

    # n printers, each with a copy printing, a finished one on its bed, and n entries waiting with a copy done
    def seed(size)
      size.times { |index| seed_printer(index) }
    end

    def seed_printer(index)
      mk4 = printer(Printer::StateFamily::Printing, name: "Printer #{index}")
      printing = entry(position: 100 + index, copies: 2)
      ended_copy(printing, mk4)
      copy(printing, mk4, 'active', started_at: 1.hour.ago)
      waiting = entry(position: index, copies: 3, same_printer: true, bound_printer: mk4, all_capable: index.odd?)
      copy(entry(position: 200 + index, copies: 2, held: true), mk4, 'enqueued')
      create(:print_job_printer, job: waiting, printer: mk4) unless waiting.all_capable?
      ended_copy(waiting, mk4)
    end

    def ended_copy(entry, printer) = copy(entry, printer, 'completed', started_at: 3.hours.ago, finished_at: 1.hour.ago)

    def query_count(size)
      Printer::Job.delete_all
      PrintQueue::Job.delete_all
      Printer.delete_all
      seed(size)
      sql_queries(cached: true) { run(query) }.size
    end

    it 'does not grow with the number of printers, entries and copies' do
      PrintQueue::Setting.current

      expect(query_count(5)).to eq query_count(1)
    end
  end
end
