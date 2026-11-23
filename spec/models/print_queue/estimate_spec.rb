# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Estimate do
  # The printers' snapshots, by printer id: Printer::Status.where reads them from here
  let(:statuses) { {} }
  # A PLA file: 2.63 g and 882.3 mm of filament, 1828 s, 123.09 × 130 mm
  let(:item) { create(:gcode_summary, :ready, :with_tools, materials: ['PLA']).item }

  before do
    allow(Printer::Status).to receive(:where) do |printer_id:|
      Array(printer_id).filter_map { |id| statuses[id] }
    end
  end

  # A printer with this filament loaded, in this state family (nil: no snapshot)
  def printer(family = Printer::StateFamily::Operational, material: 'PLA', colour: 'Black', **attributes)
    create(:printer, **attributes).tap do |printer|
      create(:printer_loaded_filament, printer:, material:, colour:)
      next unless family

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

  def copy(job, status) = create(:printer_job, :copy, print_job: job, status:, printer: create(:printer))

  def estimate(**attributes) = described_class.new(item:, **attributes)

  describe '#fits' do
    it 'is how each printer fits it, by id, with the material and colour asked for' do
      mk4 = printer
      voron = printer(material: 'PETG', colour: 'Grey')
      offline = printer(nil)
      mini = printer(bed_shape: 'circular', build_diameter: 110)

      fits = estimate(colour: 'Black').fits

      expect(fits.map { |fit| [fit.printer, fit.result] }).to eq [
        [mk4, :ready], [voron, :after_filament_change], [offline, :after_reconnect], [mini, :cannot]
      ]
      expect(fits.second.reasons.map(&:message)).to eq ['Needs PLA Black. PETG is loaded here']
      expect(estimate(material: 'PETG').fits.map(&:result)).to eq %i[after_filament_change ready after_reconnect
                                                                     cannot]
    end
  end

  describe 'the queue now' do
    before do
      first = entry(position: 1, copies: 3)
      copy(first, 'active')
      entry(position: 2, copies: 4, held: true)
      done = entry(position: 3, copies: 1)
      copy(done, 'completed')
    end

    it 'counts the copies printing and the entries with copies waiting' do
      expect(estimate).to have_attributes(printing_count: 1, waiting_jobs: 2)
    end

    it 'puts every entry waiting ahead of it at the bottom' do
      expect(estimate).to have_attributes(jobs_ahead: 2, prints_ahead: 6)
    end

    it 'puts none ahead of it at the top' do
      expect(estimate(position: 'top')).to have_attributes(jobs_ahead: 0, prints_ahead: 0)
    end
  end

  describe 'editing an entry' do
    let(:edited) { entry(position: 2, copies: 5) }

    before do
      entry(position: 1, copies: 2)
      entry(position: 3, copies: 4)
      2.times { copy(edited, 'completed') }
      copy(edited, 'active')
    end

    def edit(**attributes) = described_class.new(item: edited.item, job: edited, **attributes)

    it 'keeps its place, whatever position is given, and counts itself in the queue now' do
      expect(edit(position: 'top')).to have_attributes(waiting_jobs: 3, jobs_ahead: 1, prints_ahead: 2)
    end

    it 'counts only the copies still to start' do
      expect(edit(copies: 6)).to have_attributes(copies_to_print: 3, print_seconds: 3 * 1828)
      expect(edit(copies: 3).copies_to_print).to eq 0
    end
  end

  describe 'filament and print time' do
    it "is the summary's, times the copies to print, with the material and colour asked for" do
      totals = estimate(copies: 10, colour: 'Black')

      expect(totals).to have_attributes(copies_to_print: 10, filament_grams: 26.3, filament_millimetres: 8823,
                                        print_seconds: 18_280)
      expect(totals.filaments.map { |filament| filament.attributes.symbolize_keys }).to eq [
        { tool: 0, material: 'PLA', colour: 'Black', grams: 26.3, millimetres: 8823 }
      ]
      expect(estimate(material: 'PETG').filaments.map(&:material)).to eq ['PETG']
    end

    it 'is Not known when the summary failed, but the material asked for' do
      failed = create(:gcode_summary, :failed).item

      totals = described_class.new(item: failed, copies: 3, material: 'PLA')

      expect(totals).to have_attributes(filament_grams: nil, filament_millimetres: nil, print_seconds: nil)
      expect(totals.filaments.map { |filament| [filament.material, filament.grams] }).to eq [['PLA', nil]]
      expect(described_class.new(item: failed).filaments).to eq []
    end

    it 'is Not known while the summary is pending' do
      pending = create(:gcode_summary, status: 'pending').item

      expect(described_class.new(item: pending)).to have_attributes(filament_grams: nil, print_seconds: nil)
    end
  end

  describe '#starts' do
    it 'is what happens to it first, as if it were in the queue' do
      mk4 = printer

      expect(estimate.starts).to have_attributes(kind: :starting, printer: mk4, jobs_ahead: 0)
    end

    it 'counts the entries the printer takes before it' do
      mk4 = printer
      entry(position: 1)

      expect(estimate.starts).to have_attributes(kind: :after_current_print, printer: mk4, jobs_ahead: 1)
      expect(estimate(position: 'top').starts).to have_attributes(kind: :starting, printer: mk4)
    end

    it 'follows the printers chosen, the filament asked for and the hold' do
      printer
      voron = printer(material: 'PETG', colour: 'Grey')

      expect(estimate(all_capable: false, printer_ids: [voron.id]).starts.kind).to eq :blocked
      expect(estimate(material: 'PETG').starts).to have_attributes(kind: :starting, printer: voron)
      expect(estimate(held: true).starts.kind).to eq :on_hold
    end

    it 'waits for dispatch to resume while it is paused' do
      printer
      create(:print_queue_setting, dispatch_paused: true)

      expect(estimate.starts).to have_attributes(kind: :starting, dispatch_paused: true)
    end

    it 'is nil when no copy is left to start' do
      edited = entry(position: 1, copies: 1)
      copy(edited, 'completed')

      expect(described_class.new(item: edited.item, job: edited).starts).to be_nil
    end
  end

  it 'writes nothing' do
    printer
    entry(position: 1)

    expect { estimate(copies: 3, position: 'top').starts }.not_to(change { PrintQueue::Job.pluck(:id, :position) })
    expect { estimate.save }.to raise_error(ApplicationModel::ReadOnlyRecord)
  end
end
