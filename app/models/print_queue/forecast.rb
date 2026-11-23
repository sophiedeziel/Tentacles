# typed: true
# frozen_string_literal: true

module PrintQueue
  # What happens next to each entry of the queue (GraphQL's WhatHappensNext): a kind, and the printer when the kind
  # names one. Read-only and computed from its inputs, like the rules it reuses (PrintQueue::NextJob, Fit, Readiness),
  # so that its answer agrees with the dispatcher's: the unfinished entries (their copy counts preset, see
  # PrintQueue::NextJob.candidates), the PrintQueue::Fleet (printers, snapshots, busy printers, beds), the printer
  # each entry has a copy enqueued on (handed over, not started), and the dispatch_paused setting.
  #
  #   forecast = PrintQueue::Forecast.current # a fixed number of queries, whatever the number of entries
  #   forecast.outcome(entry) # => PrintQueue::Forecast::Outcome(kind: :after_current_print, printer: mk4), or nil
  #
  # The first that applies wins:
  #
  # | Kind                         | When                                                                  | Printer  |
  # |------------------------------|-----------------------------------------------------------------------|----------|
  # | (nil)                        | no copy waiting or enqueued: its copies are printing or finished      |          |
  # | `:starting`                  | no copy waiting, one enqueued on a printer (even held or paused)      | that one |
  # | `:on_hold`                   | held (with copies waiting)                                            |          |
  # | `:dispatch_paused`           | dispatch is paused                                                    |          |
  # | `:starting`                  | a copy is enqueued on a printer (handed over, not started yet)        | that one |
  # | `:blocked`                   | no printer that takes jobs has its filament loaded (see below)        |          |
  # | `:batch_on_printer`          | a same-printer batch bound to a printer                               | that one |
  # | `:batch_first_ready_printer` | a same-printer batch not bound yet: the first ready printer takes all |          |
  # | `:starting`                  | a free printer takes it on the next dispatch pass                     | that one |
  # | `:after_current_print`       | a busy printer takes it when its print finishes                       | that one |
  # | `:after_bed_cleared`         | a printer with a print on its bed takes it once the bed is cleared    | that one |
  # | `:next_ready_printer`        | otherwise: the next printer to be ready takes it, not assigned yet    |          |
  #
  # Which printer takes what is simulated the way the dispatcher serves printers (PrintQueue::Dispatch): each printer
  # that takes jobs and is connected takes the first entry, in queue order, that is eligible for it
  # (PrintQueue::NextJob#eligible?), fits it (PrintQueue::Fit is :ready) and has a copy left that an earlier printer
  # didn't take; an unbound same-printer batch is bound to the first printer that takes it. The free printers go
  # first (the next pass serves them), then the busy ones and those with a bed to clear, by id: which of them frees
  # up first isn't known (times come in phase 5). Each printer takes one copy, the next one. An entry gets the
  # outcome of the first printer that takes one of its copies.
  #
  # Edge cases:
  # - Offline printers (no snapshot, Offline, Connecting, Error) and printers that don't take jobs take nothing.
  # - :blocked is an eligible entry (copies waiting, its summary read) that no printer taking jobs can print as
  #   loaded: every one of them is closed to it (another printer's batch, not in its printer list), can't print it
  #   (Fit :cannot) or needs a filament change. An offline printer with the filament loaded doesn't block it: the entry
  #   waits for it to reconnect (:next_ready_printer). So every printer `cannot`, every printer not taking jobs and a
  #   printer list that names none of them all read :blocked; the page tells them apart with eligiblePrinters.
  # - An entry whose summary is pending isn't eligible yet: never :blocked, it reads :next_ready_printer (or its
  #   batch kind) until the summary is read.
  # - A same-printer batch bound to a printer reads :batch_on_printer even when that printer is busy, offline or has a
  #   bed to clear; it's :blocked when the printer it's bound to stops taking jobs or no longer has its filament.
  # - :starting from an enqueued copy wins over the rest of the entry's copies: the page lists them on expansion.
  class Forecast < ApplicationModel
    KINDS = %i[
      on_hold dispatch_paused blocked next_ready_printer after_current_print after_bed_cleared starting
      batch_on_printer batch_first_ready_printer
    ].freeze #: Array[Symbol]
    # The kinds that name a printer
    PRINTER_KINDS = %i[after_current_print after_bed_cleared starting batch_on_printer].freeze #: Array[Symbol]

    # What happens next to one entry: one of KINDS, and the printer when the kind names one (PRINTER_KINDS)
    class Outcome < ApplicationModel
      # A Symbol
      attribute :kind
      attribute :printer

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

    # The queue as it is now: the candidates, the enqueued copies (one query) and the setting, with this fleet
    #: (?fleet: PrintQueue::Fleet) -> PrintQueue::Forecast
    def self.current(fleet: PrintQueue::Fleet.current)
      entries = PrintQueue::NextJob.candidates
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

      overriding(entry) || starting_outcome || waiting_outcome(entry)
    end

    # Held, then dispatch paused: they override the rest
    #: (PrintQueue::Job entry) -> PrintQueue::Forecast::Outcome?
    def overriding(entry)
      return outcome_of(:on_hold) if entry.held?

      outcome_of(:dispatch_paused) if dispatch_paused
    end

    # For an entry with copies waiting and none enqueued
    #: (PrintQueue::Job entry) -> PrintQueue::Forecast::Outcome
    def waiting_outcome(entry)
      return outcome_of(:blocked) if blocked?(entry)
      return batch_outcome(entry) if entry.same_printer?

      takers[entry.id] || outcome_of(:next_ready_printer)
    end

    #: (PrintQueue::Job entry) -> PrintQueue::Forecast::Outcome
    def batch_outcome(entry)
      bound = fleet.printer(entry.bound_printer_id)
      bound ? outcome_of(:batch_on_printer, bound) : outcome_of(:batch_first_ready_printer)
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

    # The first outcome each entry gets from the printers that take a copy of it, by entry id (see the class comment)
    #: -> Hash[Integer, PrintQueue::Forecast::Outcome]
    def takers
      @takers ||= begin
        left, bound = before_any_take
        serving_order.each_with_object({}) do |(printer, kind), taken|
          entry = take(printer, left, bound)
          taken[entry.id] ||= outcome_of(kind, printer) if entry
        end
      end
    end

    # Before any printer takes a copy: the copies left and the printer bound to, of each entry by id
    #: -> [Hash[Integer, Integer], Hash[Integer, Integer?]]
    def before_any_take
      [entries.to_h { |entry| [entry.id, entry.waiting_count] },
       entries.to_h { |entry| [entry.id, entry.bound_printer_id] }]
    end

    # The entry the printer takes a copy of, if any, counted as taken: one copy fewer `left`, and an unbound
    # same-printer batch `bound` to the printer
    #: (Printer printer, Hash[Integer, Integer] left, Hash[Integer, Integer?] bound) -> PrintQueue::Job?
    def take(printer, left, bound)
      entry = queue_order.find { |candidate| left.fetch(candidate.id).positive? && takes?(printer, candidate, bound) }
      return unless entry

      left[entry.id] = left.fetch(entry.id) - 1
      bound[entry.id] ||= printer.id if entry.same_printer?
      entry
    end

    # Eligible for the printer (with the bindings made so far) and :ready on it
    #: (Printer printer, PrintQueue::Job entry, Hash[Integer, Integer?] bound) -> bool
    def takes?(printer, entry, bound)
      bound_to = bound[entry.id]
      return false if entry.same_printer? && bound_to && bound_to != printer.id

      next_job(printer).eligible?(entry) && fit(printer, entry).ready?
    end

    # The printers that take jobs and are connected, with the kind of what they take: the free ones first, then the
    # busy ones and those with a bed to clear, each in id order
    #: -> Array[[Printer, Symbol]]
    def serving_order
      served = fleet.printers.filter_map do |printer|
        case fleet.readiness(printer).idle_reason
        when :nothing_eligible then [printer, :starting]
        when :busy then [printer, :after_current_print]
        when :bed_not_cleared then [printer, :after_bed_cleared]
        end
      end
      served.partition { |(_, kind)| kind == :starting }.flatten(1)
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

    #: (Symbol kind, ?Printer? printer) -> PrintQueue::Forecast::Outcome
    def outcome_of(kind, printer = nil) = Outcome.new(kind:, printer:)
  end
end
