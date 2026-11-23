# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Forecast do
  # The printers' snapshots, by printer id: Printer::Status.where reads them from here
  let(:statuses) { {} }

  before do
    allow(Printer::Status).to receive(:where) do |printer_id:|
      Array(printer_id).filter_map { |id| statuses[id] }
    end
  end

  # A printer that takes jobs, with this filament loaded, in this state family (nil: no snapshot)
  def printer(family = Printer::StateFamily::Operational, material: 'PLA', colour: 'Black', **attributes)
    create(:printer, **attributes).tap do |printer|
      create(:printer_loaded_filament, printer:, material:, colour:)
      next unless family

      statuses[printer.id] = Printer::Status.new(printer_id: printer.id, state_family: family,
                                                 state_text: family.serialize.capitalize)
    end
  end

  # An entry of a PLA file whose summary is read
  def entry(materials: ['PLA'], **attributes)
    create(:print_job, **attributes).tap do |job|
      create(:gcode_summary, :ready, :with_tools, item: job.item, materials:)
    end
  end

  # A copy of the entry on the printer
  def copy(entry, printer, status, **attributes)
    create(:printer_job, :copy, print_job: entry, printer:, status:, **attributes)
  end

  # A printer printing a copy of another entry
  def printing_printer(**attributes)
    printer(Printer::StateFamily::Printing, **attributes).tap do |busy|
      copy(entry(position: 1000), busy, 'active', started_at: 10.minutes.ago)
    end
  end

  # A printer whose last print is still on its bed
  def printer_with_bed_to_clear(**attributes)
    printer(**attributes).tap do |done|
      copy(entry(position: 1000, copies: 1), done, 'completed', started_at: 2.hours.ago, finished_at: 1.hour.ago)
    end
  end

  # [kind, printer] for each entry
  def outcomes(*entries, forecast: described_class.current)
    entries.map do |queued|
      outcome = forecast.outcome(queued)
      outcome && [outcome.kind, outcome.printer]
    end
  end

  def outcome(queued, forecast: described_class.current) = outcomes(queued, forecast:).first

  describe 'each kind' do
    it 'is :starting on a free printer, which takes it on the next dispatch pass' do
      mk4 = printer

      expect(outcome(entry)).to eq [:starting, mk4]
    end

    it 'is :starting on the printer a copy is enqueued on (handed over, not started)' do
      mk4 = printing_printer
      queued = entry(copies: 2)
      copy(queued, mk4, 'enqueued')

      expect(outcome(queued)).to eq [:starting, mk4]
    end

    it 'is :next_ready_printer when no printer that takes jobs and is online can take it' do
      printer(Printer::StateFamily::Connecting)

      expect(outcome(entry)).to eq [:next_ready_printer, nil]
    end

    it 'is :after_current_print, naming the busy printer that takes it when its print finishes' do
      mk4 = printing_printer

      expect(outcome(entry)).to eq [:after_current_print, mk4]
    end

    it 'is :after_bed_cleared, naming the printer that takes it once its bed is cleared' do
      mk4 = printer_with_bed_to_clear

      expect(outcome(entry)).to eq [:after_bed_cleared, mk4]
    end

    it 'is :blocked when no printer that takes jobs has its filament loaded' do
      printer(material: 'PETG')

      expect(outcome(entry)).to eq [:blocked, nil]
    end

    it 'is :batch_on_printer, naming the printer a same-printer batch is bound to' do
      mk4 = printing_printer
      batch = entry(copies: 3, same_printer: true, bound_printer: mk4)
      copy(batch, mk4, 'completed', started_at: 2.hours.ago, finished_at: 1.hour.ago,
                                    bed_cleared_at: 30.minutes.ago, bed_cleared_by: 'person')

      expect(outcome(batch)).to eq [:batch_on_printer, mk4]
    end

    it 'is :batch_first_ready_printer for a same-printer batch not bound yet that no printer is lined up for' do
      printer(Printer::StateFamily::Offline)

      expect(outcome(entry(copies: 3, same_printer: true))).to eq [:batch_first_ready_printer, nil]
    end

    it 'is :on_hold when held' do
      printer

      expect(outcome(entry(held: true))).to eq [:on_hold, nil]
    end

    it 'is nil when nothing is left to happen: every copy is printing' do
      mk4 = printing_printer
      queued = entry
      copy(queued, mk4, 'active')

      expect(outcome(queued)).to be_nil
    end
  end

  describe 'held overrides the rest' do
    let(:mk4) { printing_printer }

    # One entry of each other kind
    def others
      batch = entry(copies: 2, same_printer: true, bound_printer: mk4)
      starting = entry(copies: 2)
      copy(starting, mk4, 'enqueued')
      [entry, entry(materials: ['PETG']), batch, entry(same_printer: true, copies: 2), starting]
    end

    it 'reads :on_hold for a held entry, whatever it would read otherwise' do
      held = others.each { |queued| queued.update!(held: true) }

      expect(outcomes(*held).map(&:first)).to all(eq :on_hold)
    end

    it 'still reads :starting for an entry whose only copy left is enqueued: holding or pausing does not stop it' do
      queued = entry(held: true)
      copy(queued, mk4, 'enqueued')
      create(:print_queue_setting, dispatch_paused: true)

      expect(outcome(queued)).to eq [:starting, mk4]
    end
  end

  describe 'dispatch paused' do
    before { create(:print_queue_setting, dispatch_paused: true) }

    def paused(queued)
      outcome = described_class.current.outcome(queued)
      [outcome.kind, outcome.dispatch_paused]
    end

    it 'is a flag on the outcome computed as if dispatch were running' do
      mk4 = printer_with_bed_to_clear
      queued = entry

      expect(outcome(queued)).to eq [:after_bed_cleared, mk4]
      expect(paused(queued)).to eq [:after_bed_cleared, true]
    end

    it 'flags every waiting kind, but not :on_hold nor a copy already enqueued' do
      mk4 = printing_printer
      starting = entry(copies: 1)
      copy(starting, mk4, 'enqueued')
      kinds = [entry, entry(materials: ['PETG']), entry(copies: 2, same_printer: true, bound_printer: mk4),
               entry(held: true), starting].map { |queued| paused(queued) }

      expect(kinds).to eq [[:after_current_print, true], [:blocked, true], [:batch_on_printer, true],
                           [:on_hold, false], [:starting, false]]
    end

    it 'is false while dispatch runs' do
      PrintQueue::Setting.current.update!(dispatch_paused: false)
      printer

      expect(paused(entry)).to eq [:starting, false]
    end
  end

  describe 'jobs ahead' do
    def ahead(*entries, forecast: described_class.current)
      entries.map do |queued|
        outcome = forecast.outcome(queued)
        [outcome.kind, outcome.printer, outcome.jobs_ahead]
      end
    end

    it 'is 0 for the first entry a printer takes, and counts the entries it takes before the others' do
      busy = printing_printer
      entries = Array.new(3) { |index| entry(position: index + 1) }

      expect(ahead(*entries)).to eq [[:after_current_print, busy, 0], [:after_current_print, busy, 1],
                                     [:after_current_print, busy, 2]]
    end

    it 'names the printer an entry limited to it waits for, after the entries it takes first' do
      ender = printer_with_bed_to_clear
      voron = printing_printer(material: 'PETG')
      bracket = entry(position: 1, copies: 10)
      gear = entry(position: 2, materials: ['PETG'])
      spool = entry(position: 3, materials: ['PETG'], all_capable: false)
      create(:print_job_printer, job: spool, printer: voron)

      expect(ahead(bracket, gear, spool)).to eq [[:after_bed_cleared, ender, 0], [:after_current_print, voron, 0],
                                                 [:after_current_print, voron, 1]]
    end

    it 'counts a batch ahead once, whatever its copies' do
      mk4 = printer
      batch = entry(position: 1, copies: 3, same_printer: true)
      later = entry(position: 2)

      expect(ahead(batch, later)).to eq [[:starting, mk4, 0], [:after_current_print, mk4, 1]]
    end

    it 'is 0 for kinds without a printer' do
      printer(material: 'PETG')
      blocked = entry

      expect(described_class.current.outcome(blocked)).to have_attributes(kind: :blocked, jobs_ahead: 0)
    end
  end

  describe 'takes_next' do
    it 'is the entry each printer takes first, as if dispatch were running' do
      create(:print_queue_setting, dispatch_paused: true)
      free = printer
      bed = printer_with_bed_to_clear
      petg = printer(material: 'PETG')
      first = entry(position: 1)
      second = entry(position: 2)
      forecast = described_class.current

      expect([free, bed, petg].map { |one| forecast.takes_next(one) }).to eq [first, second, nil]
    end

    it 'is nil for a printer offline or not taking jobs' do
      offline = printer(nil)
      off = printer(takes_jobs: false)
      entry
      forecast = described_class.current

      expect([offline, off].map { |one| forecast.takes_next(one) }).to eq [nil, nil]
    end
  end

  describe 'who takes what' do
    it 'agrees with the dispatcher on what the free printers take' do
      allow(PrintQueue).to receive_messages(enabled?: true, connector: instance_spy(PrintQueue::Connector::Spooler))
      allow(PrintQueue).to receive(:push_changed)
      mk4 = printer
      mini = printer(material: 'PETG')
      xl = printer
      entries = [entry(position: 1, copies: 2), entry(position: 2, materials: ['PETG']), entry(position: 3)]

      forecast = described_class.current
      dispatched = PrintQueue::Dispatch.new.tap(&:save!).dispatched

      # The third entry: round 2, once the first printer is done
      expect(outcomes(*entries, forecast:)).to eq [[:starting, mk4], [:starting, mini], [:after_current_print, mk4]]
      expect(dispatched.map { |copy| [copy.printer, copy.print_job] })
        .to eq [[mk4, entries[0]], [mini, entries[1]], [xl, entries[0]]]
    end

    it 'serves the free printers first, then the busy ones and the beds to clear, in id order' do
      busy = printing_printer
      bed = printer_with_bed_to_clear
      free = printer
      entries = Array.new(4) { |index| entry(position: index + 1) }

      expect(outcomes(*entries)).to eq [[:starting, free], [:after_current_print, busy], [:after_bed_cleared, bed],
                                        [:after_current_print, free]]
    end

    it 'lets a later entry overtake one that does not fit the printer' do
      mk4 = printing_printer
      petg = entry(position: 1, materials: ['PETG'])
      pla = entry(position: 2)
      printer(nil, material: 'PETG') # offline, with PETG loaded: petg waits for it

      expect(outcomes(petg, pla)).to eq [[:next_ready_printer, nil], [:after_current_print, mk4]]
    end

    it 'gives each copy of a batch its own printer' do
      mk4 = printer
      printing_printer
      batch = entry(copies: 2)
      later = entry

      # The busy printer takes the second copy: the later entry waits for the free one's next round
      expect(outcomes(batch, later)).to eq [[:starting, mk4], [:after_current_print, mk4]]
    end

    it 'lets a same-printer batch take one printer only, the one it is bound to in the simulation, and names it' do
      mk4 = printer
      mini = printer
      batch = entry(position: 1, copies: 3, same_printer: true)
      later = entry(position: 2)

      expect(outcomes(batch, later)).to eq [[:starting, mk4], [:starting, mini]]
    end

    it 'names the printer lined up for an unbound same-printer batch, whatever its state' do
      ender = printer_with_bed_to_clear
      printing_printer(material: 'PETG')

      expect(outcome(entry(copies: 2, same_printer: true))).to eq [:after_bed_cleared, ender]
    end

    it 'skips held entries, and entries limited to other printers' do
      mk4 = printer
      mini = printer
      limited = entry(position: 1, all_capable: false)
      create(:print_job_printer, job: limited, printer: mini)
      entry(position: 0, held: true)

      expect(outcome(limited)).to eq [:starting, mini]
      expect(outcome(entry(position: 2))).to eq [:starting, mk4]
    end
  end

  describe 'edge cases' do
    it 'is :next_ready_printer, not :blocked, when the only printer with its filament is offline' do
      printer(Printer::StateFamily::Offline)

      expect(outcome(entry)).to eq [:next_ready_printer, nil]
    end

    it 'is :blocked when the printer with its filament does not take jobs' do
      printer(takes_jobs: false)

      expect(outcome(entry)).to eq [:blocked, nil]
    end

    it 'is :blocked when every printer cannot print it' do
      printer(build_volume_x: 100, build_volume_y: 100)

      expect(outcome(entry)).to eq [:blocked, nil]
    end

    it 'is :blocked when its printer list names no printer with its filament' do
      printer
      limited = entry(all_capable: false)
      create(:print_job_printer, job: limited, printer: printer(material: 'PETG'))

      expect(outcome(limited)).to eq [:blocked, nil]
    end

    it 'is :blocked when there is no printer at all' do
      expect(outcome(entry)).to eq [:blocked, nil]
    end

    it 'is :next_ready_printer, not :blocked, while its summary is pending' do
      printer(material: 'PETG')
      pending = create(:print_job)
      create(:gcode_summary, item: pending.item)

      expect(outcome(pending)).to eq [:next_ready_printer, nil]
    end

    it 'is :blocked for a same-printer batch whose printer no longer has its filament' do
      mk4 = printer(material: 'PETG')
      printer

      expect(outcome(entry(copies: 2, same_printer: true, bound_printer: mk4))).to eq [:blocked, nil]
    end

    it 'ignores offline printers and printers that do not take jobs when assigning' do
      printer(Printer::StateFamily::Offline)
      printer(takes_jobs: false)
      busy = printing_printer

      expect(outcome(entry)).to eq [:after_current_print, busy]
    end
  end

  describe '.current' do
    it 'reads the queue in the same number of queries for 1 and 5 entries and printers' do
      create(:print_queue_setting)
      count = lambda do |size|
        size.times { printing_printer }
        size.times { |index| entry(position: index + 1, copies: 2) }
        queries = 0
        counter = lambda do |*, payload|
          queries += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]
        end
        ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { described_class.current.outcomes }
        queries
      end

      one = count.call(1)
      Printer::Job.delete_all
      PrintQueue::Job.delete_all
      Printer.delete_all

      expect(count.call(5)).to eq one
    end
  end
end
