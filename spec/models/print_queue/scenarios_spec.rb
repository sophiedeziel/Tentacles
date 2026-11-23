# frozen_string_literal: true

require 'rails_helper'
require 'spooler'

# The global queue end to end, as stories: the operations, the dispatcher and its rules, the bed and the print events,
# with the printers played by the fake connector (PrintQueue::Connector::Fake). The spooler is played too: each dispatch
# request runs its pass right away, as the spooler does when it gets one. So a story reads "something happens, then
# this printer got that copy".
RSpec.describe PrintQueue::Connector::Fake, 'running the global queue' do
  let(:fake) { described_class.new }
  # Each printer takes jobs, with PLA Black loaded; none is ready (no snapshot) until the story says so
  let(:mk4) { printer('Prusa MK4', bed: 250) }
  let(:mini) { printer('Prusa Mini', bed: 180) }
  let(:xl) { printer('Prusa XL', bed: 360) }
  # PLA files whose summary is read: a cube fits every bed, a plate only the XL's
  let(:cube) { gcode(width: 120) }
  let(:gear) { gcode(width: 120) }
  let(:plate) { gcode(width: 300) }

  before do
    allow(PrintQueue).to receive(:enabled?).and_return(true)
    PrintQueue.connector = fake
    redis = MockRedis.new
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 5, timeout: 1) { redis })
    allow(TentaclesSchema).to receive(:subscriptions).and_return(instance_double(GraphQL::Subscriptions, trigger: nil))
    # The spooler: a pass for each dispatch request, unless the story holds them (#in_one_pass)
    dispatch_request = instance_double(PrintQueue::DispatchRequest)
    allow(dispatch_request).to receive(:save) { @holding_requests || PrintQueue::Dispatch.new.save! }
    allow(PrintQueue::DispatchRequest).to receive(:new).and_return(dispatch_request)
  end

  def printer(name, bed:)
    create(:printer, name:, build_volume_x: bed, build_volume_y: bed, build_volume_z: 250).tap do |printer|
      create(:printer_loaded_filament, printer:, material: 'PLA', colour: 'Black')
    end
  end

  def gcode(width:)
    create(:file_record).tap do |item|
      create(:gcode_summary, :ready, :with_tools, item:, materials: ['PLA'], min_x: 0, max_x: width, min_y: 0,
                                                  max_y: 100)
    end
  end

  # Adds an entry at the bottom of the queue (PrintQueue::Addition)
  def add(item, copies: 1, **)
    PrintQueue::Addition.new(item:, copies:, **).tap(&:save!).job
  end

  # The printer's copy in the works (enqueued or active), nil when it has none
  def copy_on(printer)
    printer.jobs.find_by(status: Printer::Job::UNFINISHED_STATUSES)
  end

  # The copy's print, from start to end, on its printer
  def print!(copy, result = 'completed')
    fake.started!(copy)
    fake.progressed!(copy, 50)
    fake.ended!(copy, result)
  end

  # A person confirms the printer's bed is cleared (Bed cleared)
  def clear_bed(printer)
    PrintQueue::BedClearance.new(printer:).save!
  end

  def idle_reason(printer) = PrintQueue::Readiness.for(printer).idle_reason

  # The dispatch requests made in the block wait, then one pass runs (the spooler's sweep, or a spooler that was busy):
  # returns it
  def in_one_pass
    @holding_requests = true
    yield
    @holding_requests = false
    PrintQueue::Dispatch.new.tap(&:save!)
  end

  it 'gives two printers ready at once a copy each, in one pass' do
    first = add(cube)
    second = add(gear)
    expect(fake.commands).to be_empty # no printer is ready

    pass = in_one_pass do
      fake.ready!(mk4)
      fake.ready!(mini)
    end

    expect(pass.dispatched.map { |copy| [copy.printer, copy.print_job] }).to eq [[mk4, first], [mini, second]]
    expect(fake.received(:start)).to eq pass.dispatched
  end

  it 'lets a later entry overtake one waiting for the only printer it fits' do
    fake.ready!(mini)
    fake.offline!(xl)
    big = add(plate)
    expect(copy_on(mini)).to be_nil # too small for it
    expect(copy_on(xl)).to be_nil # offline

    small = add(cube)

    expect(copy_on(mini).print_job).to eq small
    expect(big.reload.waiting_count).to eq 1

    fake.ready!(xl)

    expect(copy_on(xl).print_job).to eq big
    expect(fake.received(:start).map(&:print_job)).to eq [small, big]
  end

  describe 'a same-printer batch' do
    let!(:batch) do
      fake.ready!(mk4)
      fake.ready!(mini)
      add(cube, copies: 3, same_printer: true)
    end

    it 'binds to the printer of its first copy, whose other copies only it prints' do
      first = copy_on(mk4)
      expect(first.print_job).to eq batch
      expect(batch.reload.bound_printer).to eq mk4
      expect(copy_on(mini)).to be_nil

      print!(first)
      expect(idle_reason(mk4)).to eq :bed_not_cleared
      expect(idle_reason(mini)).to eq :nothing_eligible # idle, but the batch isn't for it

      clear_bed(mk4)
      expect(copy_on(mk4)).to have_attributes(print_job: batch, copy_number: 2)
      expect(copy_on(mini)).to be_nil
    end

    it 'waits for its printer while it is offline, the other printer left idle, then goes on' do
      print!(copy_on(mk4))
      clear_bed(mk4)
      print!(copy_on(mk4))

      fake.offline!(mk4)
      clear_bed(mk4)

      expect(batch.reload).to have_attributes(done_count: 2, waiting_count: 1)
      expect(copy_on(mk4)).to be_nil
      expect(copy_on(mini)).to be_nil
      expect(idle_reason(mk4)).to eq :offline
      expect(idle_reason(mini)).to eq :nothing_eligible

      fake.ready!(mk4)

      third = copy_on(mk4)
      expect(third).to have_attributes(print_job: batch, copy_number: 3)
      print!(third)
      expect(batch.reload).to have_attributes(done_count: 3, unfinished?: false)
      expect(fake.received(:start).map(&:printer)).to eq [mk4, mk4, mk4]
    end
  end

  describe 'a spooler restart mid-print' do
    let(:polls) { [] }

    before do
      allow(UploadFilesToPrintersJob).to receive(:perform_now)
      allow(Spooler::Print).to receive(:new).and_wrap_original do |original, *args, **options|
        original.call(*args, **options).tap do |print|
          allow(print).to receive(:sleep)
          allow(print).to receive(:log)
        end
      end
      # The spool ends the copy: once PrintEnd (and the dispatch pass it asks for) is done, the story goes on
      allow(PrintQueue::PrintEnd).to receive(:new).and_wrap_original do |original, **attributes|
        original.call(**attributes).tap do |print_end|
          allow(print_end).to receive(:save!).and_wrap_original do |save|
            save.call.tap { @copy_ended = true }
          end
        end
      end
    end

    after { @spool.instance_variable_get(:@thread).kill.join if @spool }

    # The printer reports Printing, then Operational, which its monitor sees too (PrinterReady). At each poll, a
    # dispatch pass runs (the sweep): what it dispatched is recorded.
    def printer_prints_then_finishes(printer)
      states = %w[Printing Operational]
      allow(Octoprint::Job).to receive(:get) do
        state = states.shift
        fake.ready!(printer) if state == 'Operational'
        polls << [state, PrintQueue::Dispatch.new.tap(&:save!).dispatched]
        Octoprint::Job.deserialize({ state:, job: { file: { name: 'test.gcode' } }, progress: {} })
      end
    end

    # The spooler starts again: the printer's new spool adopts the copy it was printing, in its thread, until the copy
    # ended
    def restart_spooler(printer)
      @spool = Spooler::Spool.new(Printer.find(printer.id))
      Timeout.timeout(5) { Thread.pass until @copy_ended }
    end

    it 'adopts the copy under way without sending it again; once it ends and the bed is cleared, the next copy goes' do
      fake.ready!(mk4)
      batch = add(cube, copies: 2)
      first = copy_on(mk4)
      fake.started!(first)
      printer_prints_then_finishes(mk4)

      restart_spooler(mk4)

      expect(polls).to eq [['Printing', []], ['Operational', []]] # the printer got no other job meanwhile
      expect(UploadFilesToPrintersJob).not_to have_received(:perform_now)
      expect(fake.received(:start)).to eq [first]
      expect(first.reload.status).to eq 'completed'
      expect(mk4.bed_to_clear).to eq first
      expect(copy_on(mk4)).to be_nil

      clear_bed(mk4)

      expect(copy_on(mk4)).to have_attributes(print_job: batch, copy_number: 2)
      expect(fake.received(:start).last).to eq copy_on(mk4)
    end
  end

  it 'keeps the copies at or above the copies done or printing' do
    in_one_pass do
      fake.ready!(mk4)
      fake.ready!(mini)
    end
    entry = add(cube, copies: 3)
    print!(copy_on(mk4))

    lower = PrintQueue::CopiesChange.new(job: entry, copies: 1)
    expect(lower.save).to be false
    expect(lower.errors[:base]).to eq ["Can't go below 2: 1 done and 1 printing"]

    PrintQueue::CopiesChange.new(job: entry, copies: 2).save!
    expect(entry.reload).to have_attributes(copies: 2, done_count: 1, printing_count: 1, waiting_count: 0)
  end

  it "doesn't count a failed copy, or print it again until the copies are raised" do
    fake.ready!(mk4)
    entry = add(cube)
    print!(copy_on(mk4), 'error')
    clear_bed(mk4)

    expect(entry.reload).to have_attributes(done_count: 0, failed_count: 1, waiting_count: 0, unfinished?: false)
    expect(copy_on(mk4)).to be_nil

    PrintQueue::CopiesChange.new(job: entry, copies: 2).save!

    expect(copy_on(mk4)).to have_attributes(print_job: entry, copy_number: 2)
  end

  it 'skips a held entry' do
    held = add(cube)
    PrintQueue::Hold.new(job: held).save!
    next_one = add(gear)

    fake.ready!(mk4)

    expect(copy_on(mk4).print_job).to eq next_one
    expect(held.reload.waiting_count).to eq 1
  end

  it 'dispatches nothing while dispatch is paused, and dispatches once it resumes' do
    PrintQueue::DispatchPause.new.save!
    fake.ready!(mk4)
    entry = add(cube)

    expect(copy_on(mk4)).to be_nil
    expect(idle_reason(mk4)).to eq :dispatch_paused

    PrintQueue::DispatchResumption.new.save!

    expect(copy_on(mk4).print_job).to eq entry
  end

  it 'cancels a copy under way through the printer, and it ends cancelled once the printer stops' do
    fake.ready!(mk4)
    add(cube)
    copy = copy_on(mk4)
    fake.started!(copy)

    PrintQueue::CopyCancellation.new(printer_job: copy).save!

    expect(fake.received(:cancel)).to eq [copy]
    expect(copy.reload.status).to eq 'active'

    fake.ended!(copy)

    expect(copy.reload.status).to eq 'cancelled'
    expect(mk4.bed_to_clear).to eq copy # it had started: something is on the bed
  end
end
