# typed: true
# frozen_string_literal: true

module PrintQueue
  # What happens next to each entry of the queue (GraphQL's WhatHappensNext), and what each printer takes next
  # (Printer.takesNext). Read-only and computed from its inputs, like the rules it reuses (PrintQueue::NextJob, Fit,
  # Readiness), so that its answer agrees with the dispatcher's: the unfinished entries (their copy counts preset, see
  # PrintQueue::NextJob.candidates), the PrintQueue::Fleet (printers, snapshots, busy printers, beds), the printer
  # each entry has a copy enqueued on (handed over, not started), and the dispatch_paused setting.
  #
  #   forecast = PrintQueue::Forecast.current # a fixed number of queries, whatever the number of entries
  #   forecast.outcome(entry)    # => Outcome(kind: :after_current_print, printer: mk4, jobs_ahead: 1,
  #                              #            dispatch_paused: false), or nil
  #   forecast.takes_next(mini)  # => the entry Mini takes first, or nil
  #
  # The first that applies wins:
  #
  # | Kind                         | When                                                                  | Printer  |
  # |------------------------------|-----------------------------------------------------------------------|----------|
  # | (nil)                        | no copy waiting or enqueued: its copies are printing or finished      |          |
  # | `:starting`                  | no copy waiting, one enqueued on a printer (even held or paused)      | that one |
  # | `:on_hold`                   | held (with copies waiting)                                            |          |
  # | `:starting`                  | a copy is enqueued on a printer (handed over, not started yet)        | that one |
  # | `:blocked`                   | no printer that takes jobs has its filament loaded (see below)        |          |
  # | `:batch_on_printer`          | a same-printer batch bound to a printer                               | that one |
  # | `:starting`                  | a free printer takes it on the next dispatch pass                     | that one |
  # | `:after_current_print`       | a busy printer takes it when its print finishes, or any printer takes | that one |
  # |                              | it after `jobs_ahead` other entries                                   |          |
  # | `:after_bed_cleared`         | a printer with a print on its bed takes it once the bed is cleared    | that one |
  # | `:batch_first_ready_printer` | a same-printer batch not bound yet that no printer is lined up for    |          |
  # | `:next_ready_printer`        | otherwise: no printer is lined up for it (offline ones, pending file) |          |
  #
  # Dispatch paused is not a kind: every outcome is computed as if dispatch were running, and `dispatch_paused` says
  # it waits for dispatch to resume first. It's false for :on_hold and for a copy already enqueued (the spooler starts
  # it whatever the setting).
  #
  # Which printer takes what is simulated the way the dispatcher serves printers (PrintQueue::Dispatch), in rounds
  # (PrintQueue::Forecast::Rounds): in each round, each printer that takes jobs and is connected takes the first
  # entry, in queue order, that is eligible for it (PrintQueue::NextJob#eligible?), fits it (PrintQueue::Fit is
  # :ready) and has a copy left that an earlier take didn't take; an unbound same-printer batch is bound to the first
  # printer that takes it. The free printers go first (the next pass serves them), then the busy ones and those with a
  # bed to clear, by id (PrintQueue::Fleet#serving_order): which of them frees up first isn't known (times come in
  # phase 5). Each printer takes one copy per round, and the rounds go on until no printer takes anything. An entry
  # (an unbound same-printer batch too) gets the outcome of the first take of one of its copies: the printer's kind
  # when it's that printer's first take, :after_current_print otherwise, with `jobs_ahead` the number of other entries
  # the printer took before it (entries, not copies: a batch ahead counts once). `takes_next` is a printer's first
  # take.
  #
  # Edge cases:
  # - Offline printers (no snapshot, Offline, Connecting, Error) and printers that don't take jobs take nothing.
  # - :blocked is an eligible entry (copies waiting, its summary read) that no printer taking jobs can print as
  #   loaded: every one of them is closed to it (another printer's batch, not in its printer list), can't print it
  #   (Fit :cannot) or needs a filament change. An offline printer with the filament loaded doesn't block it: the entry
  #   waits for it to reconnect (:next_ready_printer). So every printer `cannot`, every printer not taking jobs and a
  #   printer list that names none of them all read :blocked; the page tells them apart with eligiblePrinters.
  # - An entry whose summary is pending isn't eligible yet: never :blocked, it reads :next_ready_printer (or
  #   :batch_first_ready_printer) until the summary is read.
  # - A same-printer batch bound to a printer reads :batch_on_printer even when that printer is busy, offline or has a
  #   bed to clear; it's :blocked when the printer it's bound to stops taking jobs or no longer has its filament.
  # - :starting from an enqueued copy wins over the rest of the entry's copies: the page lists them on expansion.
  # - `takes_next` is nil for a printer that takes nothing (offline, not taking jobs, nothing it can take). A printer
  #   with a copy already enqueued takes that copy first: `takes_next` is what it takes after it.
  class Forecast < ApplicationModel
    KINDS = %i[
      on_hold blocked next_ready_printer after_current_print after_bed_cleared starting batch_on_printer
      batch_first_ready_printer
    ].freeze #: Array[Symbol]
    # The kinds that name a printer
    PRINTER_KINDS = %i[after_current_print after_bed_cleared starting batch_on_printer].freeze #: Array[Symbol]
    # The kind of a printer's first take, by its idle reason (PrintQueue::Fleet#serving_order)
    FIRST_TAKE_KINDS = {
      nothing_eligible: :starting, busy: :after_current_print, bed_not_cleared: :after_bed_cleared
    }.freeze #: Hash[Symbol, Symbol]

    # What happens next to one entry: one of KINDS, the printer when the kind names one (PRINTER_KINDS), how many
    # entries that printer takes before it, and whether it waits for dispatch to resume first
    class Outcome < ApplicationModel
      # A Symbol
      attribute :kind
      attribute :printer
      attribute :jobs_ahead, :integer, default: 0
      attribute :dispatch_paused, :boolean, default: false

      # @override
      #: -> bool
      def readonly? = true
    end

    # Array[PrintQueue::Job]: the unfinished entries, their copy counts preset, their job_printers and item's summary
    # preloaded (PrintQueue::NextJob.candidates)
    attribute :entries, default: -> { [] }
    attribute :fleet, default: -> { PrintQueue::Fleet.new }
    # Hash[Integer, Integer]: the printer each entry has a copy enqueued on, by entry id (the first one enqueued)
    attribute :starting_printer_ids, default: -> { {} }
    attribute :dispatch_paused, :boolean, default: false

    # The queue as it is now: the candidates (unless given), the enqueued copies (one query) and the setting, with this
    # fleet
    #: (?fleet: PrintQueue::Fleet, ?entries: Array[PrintQueue::Job]) -> PrintQueue::Forecast
    def self.current(fleet: PrintQueue::Fleet.current, entries: PrintQueue::NextJob.candidates)
      enqueued = Printer::Job.where(print_job_id: entries.map(&:id), status: 'enqueued').in_queue_order
                             .pluck(:print_job_id, :printer_id)
      new(entries:, fleet:, starting_printer_ids: enqueued.reverse.to_h, # the first enqueued wins
          dispatch_paused: PrintQueue::Setting.dispatch_paused?)
    end

    # What happens next to the entry, nil when nothing is left to happen to it or it isn't one of `entries`
    #: (PrintQueue::Job entry) -> PrintQueue::Forecast::Outcome?
    def outcome(entry) = outcomes[entry.id]

    # By entry id: the entries with nothing left to happen are left out
    #: -> Hash[Integer, PrintQueue::Forecast::Outcome]
    def outcomes
      @outcomes ||= entries.each_with_object({}) do |entry, outcomes|
        outcome = decide(entry)
        outcomes[entry.id] = outcome if outcome
      end
    end

    # The entry the printer takes first, as if dispatch were running: nil when it takes none (see the class comment)
    #: (Printer printer) -> PrintQueue::Job?
    def takes_next(printer) = simulation.last[printer.id]&.first

    # @override
    #: -> bool
    def readonly? = true

    private

    #: (PrintQueue::Job entry) -> PrintQueue::Forecast::Outcome?
    def decide(entry)
      starting = fleet.printer(starting_printer_ids[entry.id])
      starting_outcome = outcome_of(:starting, starting) if starting
      # Nothing waiting: only the copy handed over is left to happen (holding or pausing doesn't stop it)
      return starting_outcome if entry.waiting_count.zero?
      return outcome_of(:on_hold) if entry.held?

      starting_outcome || paused(waiting_outcome(entry))
    end

    # For an entry with copies waiting, none enqueued and not held, as if dispatch were running
    #: (PrintQueue::Job entry) -> PrintQueue::Forecast::Outcome
    def waiting_outcome(entry)
      return outcome_of(:blocked) if blocked?(entry)

      bound = fleet.printer(entry.bound_printer_id) if entry.same_printer?
      return outcome_of(:batch_on_printer, bound) if bound

      simulation.first[entry.id] || outcome_of(entry.same_printer? ? :batch_first_ready_printer : :next_ready_printer)
    end

    # Its summary read (copies waiting and not held: checked before), but no printer that takes jobs can print it as
    # loaded (an offline one with its filament loaded can, once it reconnects)
    #: (PrintQueue::Job entry) -> bool
    def blocked?(entry)
      return false unless entry.needs.runnable?

      fleet.printers.select(&:takes_jobs?).none? do |printer|
        next_job(printer).eligible?(entry) && fit(printer, entry).filament_loaded?
      end
    end

    # The outcome of each entry's first take, by entry id, and the entries each printer takes, in order and once
    # each, by printer id
    #: -> [Hash[Integer, PrintQueue::Forecast::Outcome], Hash[Integer, Array[PrintQueue::Job]]]
    def simulation
      @simulation ||= begin
        taken = {} #: Hash[Integer, PrintQueue::Forecast::Outcome]
        lineups = {} #: Hash[Integer, Array[PrintQueue::Job]]
        rounds.takes.each { |(printer, entry)| taken[entry.id] ||= line_up(lineups[printer.id] ||= [], printer, entry) }
        [taken, lineups]
      end
    end

    # A printer takes a copy of an entry that is eligible for it and :ready on it
    #: -> PrintQueue::Forecast::Rounds
    def rounds
      Rounds.new(entries: queue_order, printers: fleet.serving_order,
                 ready: ->(printer, entry) { next_job(printer).eligible?(entry) && fit(printer, entry).ready? })
    end

    # Adds the entry to the printer's lineup (once) and says what this take means: the printer's own kind on its
    # first take (FIRST_TAKE_KINDS), :after_current_print with the entries ahead of it after that
    #: (Array[PrintQueue::Job] lineup, Printer printer, PrintQueue::Job entry) -> PrintQueue::Forecast::Outcome
    def line_up(lineup, printer, entry)
      lineup << entry unless lineup.last == entry
      jobs_ahead = lineup.index(entry).to_i
      return Outcome.new(kind: :after_current_print, printer:, jobs_ahead:) if jobs_ahead.positive?

      outcome_of(FIRST_TAKE_KINDS.fetch(fleet.readiness(printer).idle_reason), printer)
    end

    #: -> Array[PrintQueue::Job]
    def queue_order
      @queue_order ||= entries.sort_by { |entry| [entry.position, entry.id] }
    end

    # One per printer: it reads each entry's needs once
    #: (Printer printer) -> PrintQueue::NextJob
    def next_job(printer)
      @next_jobs ||= {} #: Hash[Integer, PrintQueue::NextJob]?
      @next_jobs[printer.id] ||= PrintQueue::NextJob.new(printer:, status: fleet.status(printer), entries:,
                                                         dispatch_paused: false)
    end

    #: (Printer printer, PrintQueue::Job entry) -> PrintQueue::Fit
    def fit(printer, entry)
      @fits ||= {} #: Hash[[Integer, Integer], PrintQueue::Fit]?
      @fits[[printer.id, entry.id]] ||= next_job(printer).fit(entry)
    end

    # The outcome, waiting for dispatch to resume first while it's paused
    #: (PrintQueue::Forecast::Outcome outcome) -> PrintQueue::Forecast::Outcome
    def paused(outcome)
      return outcome unless dispatch_paused

      Outcome.new(kind: outcome.kind, printer: outcome.printer, jobs_ahead: outcome.jobs_ahead, dispatch_paused: true)
    end

    #: (Symbol kind, ?Printer? printer) -> PrintQueue::Forecast::Outcome
    def outcome_of(kind, printer = nil) = Outcome.new(kind:, printer:)
  end
end
