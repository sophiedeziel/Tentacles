# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Dispatch do
  let(:connector) { instance_spy(PrintQueue::Connector::Spooler) }
  # The printers' snapshots, by printer id: Printer::Status.where reads them from here
  let(:statuses) { {} }

  before do
    allow(PrintQueue).to receive_messages(enabled?: true, connector:)
    allow(PrintQueue).to receive(:push_changed)
    allow(Printer::Status).to receive(:where) do |printer_id:|
      Array(printer_id).filter_map { |id| statuses[id] }
    end
  end

  # A printer that takes jobs, with PLA Black loaded, in this state family
  def printer(family = Printer::StateFamily::Operational, **attributes)
    create(:printer, **attributes).tap do |printer|
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

  def dispatch
    described_class.new.tap(&:save!)
  end

  it 'gives each ready printer a copy of its next entry' do
    first_printer = printer
    second_printer = printer
    first = entry(position: 1)
    second = entry(position: 2)

    dispatched = dispatch.dispatched

    expect(dispatched.map { |copy| [copy.printer, copy.print_job] })
      .to eq [[first_printer, first], [second_printer, second]]
  end

  it 'creates the copy enqueued, with its file, its number and the filament loaded' do
    on = printer(filament_slots: 2)
    create(:printer_loaded_filament, printer: on, slot: 2, material: 'PETG', colour: 'Galaxy Grey')
    queued = entry

    copy = dispatch.dispatched.sole

    expect(copy.reload).to have_attributes(
      printer: on, status: 'enqueued', executable: queued.item, name: 'test.gcode', print_job: queued,
      copy_number: 1, filament: [{ 'slot' => 1, 'material' => 'PLA', 'colour' => 'Black' },
                                 { 'slot' => 2, 'material' => 'PETG', 'colour' => 'Galaxy Grey' }]
    )
  end

  it 'gives a printer one copy per pass' do
    on = printer
    first = entry(position: 1, copies: 2)
    entry(position: 2)

    expect(dispatch.dispatched.map { |copy| [copy.printer, copy.print_job] }).to eq [[on, first]]
    expect(on.jobs.count).to eq 1
  end

  it 'gives two printers two copies of one entry, numbered after the existing copies' do
    first_printer = printer
    second_printer = printer
    queued = entry(copies: 4)
    create(:printer_job, :copy, print_job: queued, status: 'completed')

    dispatched = dispatch.dispatched

    expect(dispatched.map { |copy| [copy.printer, copy.copy_number] }).to eq [[first_printer, 2], [second_printer, 3]]
  end

  it 'gives no printer a copy that is not there' do
    printer
    second_printer = printer
    queued = entry(position: 1, copies: 1)
    other = entry(position: 2)

    dispatched = dispatch.dispatched

    expect(dispatched.map(&:print_job)).to eq [queued, other]
    expect(dispatched.last.printer).to eq second_printer
  end

  describe 'printers skipped' do
    let!(:queued) { entry(copies: 5) }

    it 'skips a printer with an unfinished job of its own, or a copy' do
      old_style = printer
      create(:printer_job, printer: old_style, status: 'enqueued')
      printing = printer
      create(:printer_job, :copy, printer: printing, print_job: queued, status: 'active')
      free = printer

      expect(dispatch.dispatched.map(&:printer)).to eq [free]
    end

    it 'skips a printer that is offline, without a snapshot, busy, paused, or not taking jobs' do
      printer(Printer::StateFamily::Offline)
      printer.tap { |without| statuses.delete(without.id) }
      printer(Printer::StateFamily::Printing)
      printer(Printer::StateFamily::Paused)
      printer(takes_jobs: false)

      expect(dispatch.dispatched).to be_empty
      expect(Printer::Job.count).to eq 0
    end

    it 'skips a printer whose bed needs clearing, its last copy still on the bed' do
      uncleared = printer
      create(:printer_job, :copy, printer: uncleared, print_job: queued, status: 'completed',
                                  started_at: 2.hours.ago, finished_at: 1.hour.ago)
      cleared = printer
      create(:printer_job, :copy, printer: cleared, print_job: queued, status: 'completed',
                                  started_at: 2.hours.ago, finished_at: 1.hour.ago,
                                  bed_cleared_at: 1.minute.ago, bed_cleared_by: 'person')

      expect(dispatch.dispatched.map(&:printer)).to eq [cleared]
    end

    it 'reads the beds of the printers that take jobs at once' do
      ids = [printer.id, printer.id]
      printer(takes_jobs: false)
      allow(Printer).to receive(:ids_with_bed_to_clear).and_call_original

      dispatch

      expect(Printer).to have_received(:ids_with_bed_to_clear).once.with(ids)
    end

    it 'reads the snapshots once, of the printers that take jobs' do
      ids = [printer.id, printer.id]
      printer(takes_jobs: false)

      dispatch

      expect(Printer::Status).to have_received(:where).once.with(printer_id: ids)
    end
  end

  it 'dispatches nothing while dispatch is paused' do
    create(:print_queue_setting, dispatch_paused: true)
    printer
    entry

    expect(dispatch.dispatched).to be_empty
    expect(Printer::Job.count).to eq 0
    expect(PrintQueue).not_to have_received(:push_changed)
  end

  describe 'same-printer batches' do
    it 'binds an unbound batch to the printer of its first copy, so the next printer skips it' do
      first_printer = printer
      printer
      batch = entry(same_printer: true, copies: 3)

      expect(dispatch.dispatched.map(&:printer)).to eq [first_printer]
      expect(batch.reload.bound_printer).to eq first_printer
    end
  end

  describe 'after the commit' do
    it 'starts each copy through the connector, then pushes once with the printers that got one' do
      first_printer = printer
      second_printer = printer
      entry(copies: 2)

      dispatched = dispatch.dispatched

      dispatched.each { |copy| expect(connector).to have_received(:start).once.with(copy) }
      expect(PrintQueue).to have_received(:push_changed).once.with([first_printer, second_printer])
    end

    it 'neither starts nor pushes when nothing is dispatched' do
      printer

      dispatch

      expect(connector).not_to have_received(:start)
      expect(PrintQueue).not_to have_received(:push_changed)
    end
  end

  it 'does nothing while the global queue is off' do
    allow(PrintQueue).to receive(:enabled?).and_return(false)
    allow(PrintQueue::Setting).to receive(:lock_current)
    printer
    entry

    expect(described_class.new.save!).to be true
    expect(Printer::Job.count).to eq 0
    expect(PrintQueue::Setting).not_to have_received(:lock_current)
    expect(PrintQueue).not_to have_received(:push_changed)
  end

  # Two passes (two spooler messages, or a message and the sweep) in two threads, each with its own connection and
  # transaction: the rows must be committed for the other connection to see them, so the rows are deleted by hand.
  describe 'two passes at once' do
    self.use_transactional_tests = false

    let!(:printers) { [printer, printer] }
    let!(:entries) { [entry(position: 1, copies: 3), entry(position: 2, copies: 3)] }
    # The first pass waits inside its transaction until the second one is waiting for the queue's lock
    let(:first_holds_its_locks) { Queue.new }
    let(:second_asks_for_the_lock) { Queue.new }
    let(:release_first) { Queue.new }
    # When each pass got the queue's lock, and whether a transaction was open when a copy was started
    let(:locked_at) { {} }
    let(:started_in_transaction) { [] }

    before do
      allow(Printer::Status).to receive(:where) do |printer_id:|
        if Thread.current[:pass] == :first
          first_holds_its_locks << true
          release_first.pop(timeout: 10)
        end
        Array(printer_id).filter_map { |id| statuses[id] }
      end
      allow(PrintQueue::Setting).to receive(:lock_current).and_wrap_original do |original|
        second_asks_for_the_lock << true if Thread.current[:pass] == :second
        original.call.tap { locked_at[Thread.current[:pass]] = Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      end
      allow(connector).to receive(:start) do
        started_in_transaction << ActiveRecord::Base.connection.transaction_open?
      end
    end

    after do
      printer_ids = printers.map(&:id)
      Printer::Job.where(printer_id: printer_ids).delete_all
      PrintQueue::Job.where(id: entries.map(&:id)).delete_all
      entries.each { |job| job.item.file.purge }
      Library::Item.where(id: entries.map(&:file_record_id)).delete_all # and their summaries (cascade)
      Printer.where(id: printer_ids).delete_all # and their loaded filaments (cascade)
      PrintQueue::Setting.delete_all
    end

    # A pass in a thread of its own, on a connection of its own
    def pass_in_thread(name)
      Thread.new do
        Thread.current[:pass] = name
        ActiveRecord::Base.connection_pool.with_connection { described_class.new.tap(&:save!).dispatched }
      end
    end

    it 'never gives one printer two jobs: the second pass waits for the first and finds the printers busy' do
      first = pass_in_thread(:first)
      expect(first_holds_its_locks.pop(timeout: 10)).to be true
      second = pass_in_thread(:second)
      expect(second_asks_for_the_lock.pop(timeout: 10)).to be true
      sleep(0.3) # Its SELECT ... FOR UPDATE waits on the first pass's lock
      released_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      release_first << true

      first_dispatched = first.value
      second_dispatched = second.value

      expect(first_dispatched.map { |copy| [copy.printer_id, copy.print_job_id] })
        .to eq [[printers.first.id, entries.first.id], [printers.last.id, entries.first.id]]
      expect(second_dispatched).to be_empty
      expect(locked_at.fetch(:second)).to be > released_at
      expect(Printer::Job.where(printer_id: printers.map(&:id)).group(:printer_id).count)
        .to eq(printers.first.id => 1, printers.last.id => 1)
      expect(first_dispatched.map(&:copy_number)).to eq [1, 2]
      expect(started_in_transaction).to eq [false, false]
    end
  end
end
