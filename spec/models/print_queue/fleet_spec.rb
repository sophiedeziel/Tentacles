# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Fleet do
  let(:statuses) { {} }

  before do
    allow(Printer::Status).to receive(:where) do |printer_id:|
      Array(printer_id).filter_map { |id| statuses[id] }
    end
  end

  def printer(family = Printer::StateFamily::Operational, **attributes)
    create(:printer, **attributes).tap do |printer|
      statuses[printer.id] = Printer::Status.new(printer_id: printer.id, state_family: family, state_text: 'x')
    end
  end

  def entry(**attributes) = create(:print_job, **attributes)

  describe '#available' do
    it 'lists the printers that take jobs, connected, idle, without a job to finish and with a clear bed' do
      free = printer
      printer(takes_jobs: false)
      printer(Printer::StateFamily::Offline)
      printer(Printer::StateFamily::Printing)
      create(:printer_job, printer: printer, status: 'enqueued')
      create(:printer_job, :copy, printer: printer, status: 'completed', started_at: 2.hours.ago,
                                  finished_at: 1.hour.ago)
      create(:print_queue_setting, dispatch_paused: true)

      expect(described_class.current.available).to eq [free]
    end
  end

  describe '#bed_to_clear' do
    it 'lists the printers whose last print is still on the bed, whether they take jobs or not' do
      on_bed = printer(takes_jobs: false)
      create(:printer_job, :copy, printer: on_bed, status: 'error', started_at: 2.hours.ago, finished_at: 1.hour.ago)
      printer

      expect(described_class.current.bed_to_clear).to eq [on_bed]
    end
  end

  describe '#capable' do
    it 'lists the printers open to the entry and big enough for it, loaded filament and state aside' do
      small = printer(build_volume_x: 100, build_volume_y: 100)
      big = printer(Printer::StateFamily::Offline, takes_jobs: false)
      printer # not listed
      queued = entry(all_capable: false)
      [small, big].each { |listed| create(:print_job_printer, job: queued, printer: listed) }
      create(:gcode_summary, :ready, :with_tools, item: queued.item, materials: ['PETG'])

      expect(described_class.current.capable(queued)).to eq [big]
    end
  end

  it 'leaves the snapshots out when Redis cannot be reached: every printer is offline' do
    printer
    allow(Printer::Status).to receive(:where).and_raise(Redis::CannotConnectError)

    expect(described_class.current.available).to eq []
  end
end
