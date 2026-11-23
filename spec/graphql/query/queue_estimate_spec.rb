# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query queueEstimate', type: :request do
  # The printers' snapshots, by printer id: Printer::Status.where reads them from here
  let(:statuses) { {} }
  # 2.63 g and 882.3 mm of PLA, 1828 s
  let(:file) { create(:gcode_summary, :ready, :with_tools, materials: ['PLA']).item }
  let(:query) do
    <<~GQL
      query($fileId: ID!, $copies: Int, $material: String, $colour: String, $samePrinter: Boolean,
            $printerIds: [ID!], $position: MovePrintJobTo, $held: Boolean, $printJobId: ID) {
        queueEstimate(fileId: $fileId, copies: $copies, material: $material, colour: $colour,
                      samePrinter: $samePrinter, printerIds: $printerIds, position: $position, held: $held,
                      printJobId: $printJobId) {
          printing waitingJobs jobsAhead printsAhead copiesToPrint
          filaments { tool material colour grams metres }
          filamentGrams filamentMetres printSeconds
          starts { kind printer { name } jobsAhead dispatchPaused startsAt }
        }
      }
    GQL
  end

  before do
    allow(PrintQueue).to receive(:enabled?).and_return(true)
    allow(Printer::Status).to receive(:where) do |printer_id:|
      Array(printer_id).filter_map { |id| statuses[id] }
    end
  end

  def estimate(**arguments)
    post '/graphql', params: { query:, variables: { fileId: file.id, **arguments }.to_json }
    body = response.parsed_body
    expect(body['errors']).to be_nil
    body.dig('data', 'queueEstimate')
  end

  def printer(name = 'Prusa MK4')
    create(:printer, name:).tap do |printer|
      create(:printer_loaded_filament, printer:, material: 'PLA', colour: 'Black')
      statuses[printer.id] = Printer::Status.new(printer_id: printer.id,
                                                 state_family: Printer::StateFamily::Operational,
                                                 state_text: 'Operational')
    end
  end

  def entry(**attributes)
    create(:print_job, **attributes).tap do |job|
      create(:gcode_summary, :ready, :with_tools, item: job.item, materials: ['PLA'])
    end
  end

  it 'is the queue now, the totals of the copies and what happens to it first' do
    printer
    entry(position: 1, copies: 2)

    expect(estimate(copies: 10, colour: 'Black')).to eq(
      'printing' => 0, 'waitingJobs' => 1, 'jobsAhead' => 1, 'printsAhead' => 2, 'copiesToPrint' => 10,
      'filaments' => [{ 'tool' => 0, 'material' => 'PLA', 'colour' => 'Black', 'grams' => 26.3,
                        'metres' => 8.823 }],
      'filamentGrams' => 26.3, 'filamentMetres' => 8.823, 'printSeconds' => 18_280,
      'starts' => { 'kind' => 'AFTER_CURRENT_PRINT', 'printer' => { 'name' => 'Prusa MK4' }, 'jobsAhead' => 1,
                    'dispatchPaused' => false, 'startsAt' => nil }
    )
  end

  it 'goes before every entry at the top' do
    printer
    entry(position: 1, copies: 2)

    expect(estimate(position: 'TOP')).to include('jobsAhead' => 0, 'printsAhead' => 0,
                                                 'starts' => include('kind' => 'STARTING'))
  end

  it 'follows the hold, the printers chosen and the material asked for' do
    printer
    other = printer('Voron 2.4')

    expect(estimate(held: true)['starts']).to include('kind' => 'ON_HOLD')
    expect(estimate(printerIds: [other.id])['starts']).to include('printer' => { 'name' => 'Voron 2.4' })
  end

  it 'is blocked for a material no printer has loaded' do
    printer

    expect(estimate(material: 'PETG')).to include('starts' => include('kind' => 'BLOCKED'),
                                                  'filaments' => [include('material' => 'PETG')])
  end

  it 'replaces the print job edited, counting only its copies still to start' do
    edited = entry(position: 2, copies: 4)
    entry(position: 1)
    create(:printer_job, :copy, print_job: edited, status: 'completed')

    expect(estimate(printJobId: edited.id, copies: 4, position: 'TOP')).to include(
      'waitingJobs' => 2, 'jobsAhead' => 1, 'printsAhead' => 1, 'copiesToPrint' => 3, 'printSeconds' => 3 * 1828
    )
  end

  it "reads the print job's own file with printJobId, whatever fileId says" do
    edited = entry(copies: 2)
    edited.item.gcode_summary.update!(print_seconds: 600)

    expect(estimate(printJobId: edited.id, fileId: file.id, copies: 2)).to include('printSeconds' => 2 * 600)
  end

  it 'leaves the totals out when they are not known' do
    file.gcode_summary.update!(status: 'failed', print_seconds: nil)

    expect(estimate).to include('filamentGrams' => nil, 'filamentMetres' => nil, 'printSeconds' => nil,
                                'filaments' => [])
  end

  it 'is null for an unknown file or print job' do
    expect(estimate(fileId: file.id + 1)).to be_nil
    expect(estimate(printJobId: 0)).to be_nil
  end

  it 'is null while the global queue is off' do
    allow(PrintQueue).to receive(:enabled?).and_return(false)

    expect(estimate).to be_nil
  end
end
