# frozen_string_literal: true

require 'rails_helper'

# The global queue as a printer's page reads it: Printer.upNext, skipped, PrintJob.waitingPosition and
# LoadedFilament.waitingJobsAskingCount (bedNeedsClearing and printOnBed: printer_bed_spec.rb)
RSpec.describe 'Query printer, its global queue fields', type: :request do
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
    body['data']
  end

  def printer_fields(printer, fields)
    run("query($id: ID!) { printer(id: $id) { #{fields} } }", id: printer.id)['printer']
  end

  # The SQL queries the block runs, the ones the query cache answers included
  def sql_queries(&)
    queries = []
    counter = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name])
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    queries
  end

  # A printer with this filament loaded, in this state family
  def printer(family = Printer::StateFamily::Operational, name: 'Prusa MK4', material: 'PLA', colour: 'Black',
              **attributes)
    create(:printer, name:, **attributes).tap do |printer|
      create(:printer_loaded_filament, printer:, material:, colour:)
      statuses[printer.id] = Printer::Status.new(printer_id: printer.id, state_family: family,
                                                 state_text: family.serialize.capitalize)
    end
  end

  # An entry whose summary is read: one tool per material
  def entry(materials: ['PLA'], **attributes)
    create(:print_job, **attributes).tap do |job|
      create(:gcode_summary, :ready, :with_tools, item: job.item, materials:)
    end
  end

  def copy(entry, printer, status, **attributes)
    create(:printer_job, :copy, print_job: entry, printer:, status:, **attributes)
  end

  def id(record) = record.id.to_s

  describe 'upNext and skipped' do
    let(:query) do
      <<~GRAPHQL
        query($id: ID!) {
          printer(id: $id) {
            upNext { id waitingPosition held file { filename } whatHappensNext { kind printer { name } } }
            skipped { printJob { id waitingPosition } reasons }
          }
          globalQueue { waiting { id whatHappensNext { kind printer { name } } } }
        }
      GRAPHQL
    end

    it 'splits the waiting print jobs between the two, in queue order, with their place in the queue' do
      mk4 = printer
      voron = printer(name: 'Voron 2.4')
      first = entry(position: 1)
      petg = entry(position: 2, materials: ['PETG'])
      held = entry(position: 3, held: true)
      limited = entry(position: 4, all_capable: false)
      create(:print_job_printer, job: limited, printer: voron)
      white = entry(position: 5, colour: 'White')
      printing = entry(position: 0)
      copy(printing, mk4, 'active')

      data = run(query, id: mk4.id)

      expect(data['printer']['upNext']).to eq [
        { 'id' => id(first), 'waitingPosition' => 1, 'held' => false, 'file' => { 'filename' => 'test.gcode' },
          'whatHappensNext' => { 'kind' => 'STARTING', 'printer' => { 'name' => 'Voron 2.4' } } },
        { 'id' => id(held), 'waitingPosition' => 3, 'held' => true, 'file' => { 'filename' => 'test.gcode' },
          'whatHappensNext' => { 'kind' => 'ON_HOLD', 'printer' => nil } }
      ]
      expect(data['printer']['skipped']).to eq [
        { 'printJob' => { 'id' => id(petg), 'waitingPosition' => 2 }, 'reasons' => ['Needs PETG. PLA is loaded here'] },
        { 'printJob' => { 'id' => id(limited), 'waitingPosition' => 4 }, 'reasons' => ['Limited to Voron 2.4'] },
        { 'printJob' => { 'id' => id(white), 'waitingPosition' => 5 },
          'reasons' => ['Needs PLA White. PLA Black is loaded here'] }
      ]
    end

    it 'says what happens next as globalQueue does' do
      mk4 = printer(Printer::StateFamily::Printing)
      printer(name: 'Prusa XL')
      copy(entry(position: 0), mk4, 'active')
      entry(position: 1, copies: 2, same_printer: true, bound_printer: mk4)
      entry(position: 2)
      entry(position: 3)
      entry(position: 4, held: true)

      data = run(query, id: mk4.id)

      waiting = data['globalQueue']['waiting'].index_by { |job| job['id'] }
      expect(data['printer']['upNext'].size).to eq 4
      data['printer']['upNext'].each do |job|
        expect(job['whatHappensNext']).to eq waiting.fetch(job['id'])['whatHappensNext']
      end
    end

    it 'are empty while the global queue is off' do
      mk4 = printer
      entry
      entry(materials: ['PETG'])
      allow(PrintQueue).to receive(:enabled?).and_return(false)

      expect(printer_fields(mk4, 'upNext { id } skipped { reasons }')).to eq('upNext' => [], 'skipped' => [])
    end

    it 'run a number of SQL queries that does not grow with the print jobs' do
      seed = lambda do |size|
        PrintQueue::Job.delete_all
        size.times do |index|
          entry(position: index, copies: 3)
          entry(position: 100 + index, materials: ['PETG'])
          batch = entry(position: 200 + index, all_capable: false, same_printer: true)
          create(:print_job_printer, job: batch, printer: Printer.first)
        end
      end
      count = lambda do
        sql_queries do
          printer_fields(Printer.first, <<~FIELDS)
            upNext {
              id waitingPosition copiesLeftToStart file { filename } needs { filaments { material } }
              eligiblePrinters { name } whatHappensNext { kind printer { name } }
            }
            skipped { printJob { id waitingPosition file { filename } } reasons }
            loadedFilaments { waitingJobsAskingCount }
          FIELDS
        end.size
      end
      printer
      printer(name: 'Voron 2.4')
      PrintQueue::Setting.current

      seed.call(1)
      one = count.call
      seed.call(5)

      expect(count.call).to eq one
    end
  end

  describe 'loadedFilaments.waitingJobsAskingCount' do
    it 'counts the waiting print jobs asking for exactly that filament' do
      white = printer(colour: 'White')
      black = printer(name: 'Voron 2.4')
      entry(colour: 'White')
      entry(colour: 'white', held: true)
      entry # Any colour

      expect(printer_fields(white, 'loadedFilaments { waitingJobsAskingCount }'))
        .to eq('loadedFilaments' => [{ 'waitingJobsAskingCount' => 2 }])
      expect(printer_fields(black, 'loadedFilaments { waitingJobsAskingCount }'))
        .to eq('loadedFilaments' => [{ 'waitingJobsAskingCount' => 0 }])
    end

    it 'is 0 while the global queue is off' do
      white = printer(colour: 'White')
      entry(colour: 'White')
      allow(PrintQueue).to receive(:enabled?).and_return(false)

      expect(printer_fields(white, 'loadedFilaments { waitingJobsAskingCount }'))
        .to eq('loadedFilaments' => [{ 'waitingJobsAskingCount' => 0 }])
    end
  end
end
