# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::NextJob do
  let(:printer) { create(:printer, build_volume_x: 250, build_volume_y: 210, build_volume_z: 220) }
  let(:operational) do
    Printer::Status.new(printer_id: printer.id, state_family: Printer::StateFamily::Operational,
                        state_text: 'Operational')
  end

  before { create(:printer_loaded_filament, printer:, material: 'PLA', colour: 'Black') }

  # An entry whose file's summary is read (ready), with one tool per material
  def entry(materials: ['PLA'], **attributes)
    create(:print_job, **attributes).tap do |job|
      create(:gcode_summary, :ready, :with_tools, item: job.item, materials:)
    end
  end

  def next_job(dispatch_paused: false, status: operational, on: printer)
    described_class.new(printer: on, status:, dispatch_paused:, entries: described_class.candidates)
  end

  it 'is the first entry in position order' do
    second = entry(position: 2)
    first = entry(position: 1)

    expect(next_job.job).to eq first
    expect(next_job.job).not_to eq second
  end

  it 'sorts the entries it is given by position' do
    second = entry(position: 2)
    first = entry(position: 1)

    picked = described_class.new(printer:, status: operational, entries: [second, first]).job

    expect(picked).to eq first
  end

  it 'is nil when the queue is empty' do
    expect(next_job.job).to be_nil
  end

  it 'skips a held entry' do
    entry(position: 1, held: true)
    unheld = entry(position: 2)

    expect(next_job.job).to eq unheld
  end

  it 'skips an entry with no copy waiting (its copies are printing)' do
    printing = entry(position: 1)
    create(:printer_job, :copy, print_job: printing, status: 'active')
    waiting = entry(position: 2)

    expect(next_job.job).to eq waiting
  end

  it 'skips an entry whose summary is pending, or not there yet' do
    create(:gcode_summary, item: create(:print_job, position: 1).item) # pending
    create(:print_job, position: 2) # a .gcode without a summary
    read = entry(position: 3)

    expect(next_job.job).to eq read
  end

  it 'takes an entry whose summary failed: it fits every printer' do
    failed = create(:print_job, position: 1)
    create(:gcode_summary, :failed, item: failed.item)
    printer.loaded_filaments.destroy_all

    expect(next_job.job).to eq failed
  end

  describe 'printers' do
    let(:other) { create(:printer) }

    it 'takes an entry limited to printers that include this one' do
      listed = entry(all_capable: false, printers: [other, printer])

      expect(next_job.job).to eq listed
    end

    it 'skips an entry limited to other printers' do
      entry(position: 1, all_capable: false, printers: [other])
      next_one = entry(position: 2)

      expect(next_job.job).to eq next_one
    end
  end

  describe 'binding' do
    let(:other) { create(:printer) }

    it 'takes a same-printer batch bound to this printer' do
      bound = entry(same_printer: true, bound_printer: printer)

      expect(next_job.job).to eq bound
    end

    it 'takes a same-printer batch not bound yet' do
      unbound = entry(same_printer: true, bound_printer: nil)

      expect(next_job.job).to eq unbound
    end

    it 'skips a same-printer batch bound to another printer' do
      entry(position: 1, same_printer: true, bound_printer: other)
      next_one = entry(position: 2)

      expect(next_job.job).to eq next_one
    end

    it 'ignores a bound printer once the batch no longer keeps to one printer' do
      released = entry(same_printer: false, bound_printer: other)

      expect(next_job.job).to eq released
    end
  end

  it 'is nil while dispatch is paused' do
    entry

    expect(next_job(dispatch_paused: true).job).to be_nil
  end

  it 'is nil while the printer is offline: nothing fits it now' do
    entry

    expect(next_job(status: nil).job).to be_nil
  end

  describe 'overtaking' do
    it 'takes a later entry when the first needs another filament' do
      entry(position: 1, materials: ['PETG'])
      pla = entry(position: 2)

      expect(next_job.job).to eq pla
    end

    it 'takes a later entry when the first can never print here' do
      too_big = entry(position: 1)
      too_big.item.gcode_summary.update!(max_x: 400)
      fits = entry(position: 2)

      expect(next_job.job).to eq fits
    end
  end

  describe '#eligible? and #fit' do
    it 'explain why an entry was skipped' do
      held = entry(held: true, materials: ['PETG'])
      candidates = described_class.candidates
      job = described_class.new(printer:, status: operational, entries: candidates)

      expect(job.eligible?(candidates.first)).to be false
      expect(job.fit(held).result).to eq :after_filament_change
    end
  end

  describe '.candidates' do
    it 'are the unfinished entries in queue order, with their counts preset' do
      later = entry(position: 2, copies: 3)
      create(:printer_job, :copy, print_job: later, status: 'completed')
      finished = entry(position: 1)
      create(:printer_job, :copy, print_job: finished, status: 'completed')
      first = entry(position: 0)

      candidates = described_class.candidates

      expect(candidates).to eq [first, later]
      expect(candidates.map { |job| job.instance_variable_get(:@copy_counts) }).to all(be_present)
      expect(candidates.last.waiting_count).to eq 2
    end

    it 'narrows a scope (the dispatcher passes a locked one)' do
      kept = entry(position: 1)
      entry(position: 2)

      expect(described_class.candidates(PrintQueue::Job.where(id: kept.id))).to eq [kept]
    end
  end

  it 'picks among preloaded candidates without a query per entry or printer' do
    entry(position: 1, held: true)
    entry(position: 2, materials: ['PETG'])
    entry(position: 3, all_capable: false, printers: [create(:printer)])
    entry(position: 4)
    candidates = described_class.candidates
    loaded = Printer.includes(:loaded_filaments).find(printer.id)

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      described_class.new(printer: loaded, status: operational, entries: candidates).job
    end

    expect(queries).to be_empty
  end

  describe '.for' do
    it 'is nil when the setting pauses dispatch' do
      allow(Printer::Status).to receive(:find_by).and_return(operational)
      create(:print_queue_setting, dispatch_paused: true)
      entry

      expect(described_class.for(printer).job).to be_nil
    end
  end
end
