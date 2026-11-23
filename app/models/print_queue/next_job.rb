# typed: true
# frozen_string_literal: true

module PrintQueue
  # The entry a printer prints next: the first of `entries`, in position order, that is eligible for it (#eligible?)
  # and fits it (PrintQueue::Fit is :ready). nil when dispatch is paused, or when none does.
  #
  # Its inputs are passed in so the dispatcher can run it for several printers inside its transaction without a query
  # per entry or printer: the candidate entries with their counts preset (see .candidates), the printer with its
  # loaded_filaments, its Printer::Status snapshot (nil when it has none) and the dispatch_paused setting.
  #
  #   entries = PrintQueue::NextJob.candidates
  #   statuses = Printer::Status.where(printer_id: printers.map(&:id)).index_by(&:printer_id)
  #   printers.each do |printer|
  #     next_job = PrintQueue::NextJob.new(printer:, status: statuses[printer.id], entries:, dispatch_paused: false)
  #     next_job.job # => a PrintQueue::Job, or nil
  #   end
  #
  # For one printer, reading everything (the console, GraphQL later):
  #
  #   PrintQueue::NextJob.for(printer).job
  class NextJob < ApplicationModel
    attribute :printer
    attribute :status
    # Array[PrintQueue::Job], their copy counts preset; sorted by position here
    attribute :entries, default: -> { [] }
    attribute :dispatch_paused, :boolean, default: false

    # The unfinished entries of `scope` (the dispatcher passes a locked one), in queue order, with what the rules read
    # preloaded and their copy counts read in one query
    #: (?PrintQueue::Job::PrivateRelation scope) -> Array[PrintQueue::Job]
    def self.candidates(scope = PrintQueue::Job.all)
      entries = scope.unfinished.in_queue_order
                     .includes(:job_printers, item: [{ gcode_summary: :tools }, { file_attachment: :blob }]).to_a
      counts = PrintQueue::Job.copy_counts(entries.map(&:id))
      entries.each { |entry| entry.copy_counts = counts.fetch(entry.id) }
    end

    # The next job of one printer, reading its snapshot (Redis), the setting and the candidates
    #: (Printer printer, ?status: Printer::Status?, ?dispatch_paused: bool) -> PrintQueue::NextJob
    def self.for(printer, status: Printer::Status.find_by(printer_id: printer.id),
                 dispatch_paused: PrintQueue::Setting.dispatch_paused?)
      new(printer:, status:, dispatch_paused:, entries: candidates)
    end

    # The entry to print next, nil when there's none (or dispatch is paused)
    #: -> PrintQueue::Job?
    def job
      return @job if defined?(@job)

      @job = dispatch_paused ? nil : queue_order.find { |entry| eligible?(entry) && fit(entry).ready? }
    end

    # Whether the entry may go to this printer, before its fit: copies waiting, not held, its summary read (not
    # pending), allowed on this printer (all_capable, or listed), and not bound to another printer (a same-printer
    # batch bound to this printer, or not bound yet, is fine)
    #: (PrintQueue::Job entry) -> bool
    def eligible?(entry)
      entry.waiting_count.positive? && !entry.held? && needs(entry).runnable? &&
        allowed?(entry) && unbound_or_here?(entry)
    end

    # How the entry fits this printer
    #: (PrintQueue::Job entry) -> PrintQueue::Fit
    def fit(entry)
      PrintQueue::Fit.new(needs: needs(entry), printer:, status:)
    end

    # @override
    #: -> bool
    def readonly? = true

    private

    #: -> Array[PrintQueue::Job]
    def queue_order = entries.sort_by { |entry| [entry.position, entry.id] }

    # Read once per entry: the needs don't depend on the printer
    #: (PrintQueue::Job entry) -> PrintQueue::Needs
    def needs(entry)
      @needs ||= {} #: Hash[Integer, PrintQueue::Needs]?
      @needs[entry.id] ||= entry.needs
    end

    # From the preloaded job_printers: no query
    #: (PrintQueue::Job entry) -> bool
    def allowed?(entry)
      entry.all_capable? || entry.job_printers.any? { |job_printer| job_printer.printer_id == printer.id }
    end

    #: (PrintQueue::Job entry) -> bool
    def unbound_or_here?(entry)
      !entry.same_printer? || entry.bound_printer_id.nil? || entry.bound_printer_id == printer.id
    end
  end
end
