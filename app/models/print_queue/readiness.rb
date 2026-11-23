# typed: true
# frozen_string_literal: true

module PrintQueue
  # Whether a printer can take a job from the global queue, and why not (its idle reason). For the global queue only:
  # Printer.start_next_blocker stays the rule of the per-printer queue until the cutover (phase 6).
  #
  # Computed from its inputs, so the dispatcher can check several printers inside its transaction without a query per
  # printer: the printer (takes_jobs), its Printer::Status snapshot (nil when it has none), whether it has an
  # unfinished printer_jobs row, whether its bed needs clearing, the dispatch_paused setting, and the entry
  # PrintQueue::NextJob found for it.
  #
  #   readiness = PrintQueue::Readiness.new(printer:, status:, has_unfinished_job: false, bed_needs_clearing: false,
  #                                         dispatch_paused: false, next_job: entry)
  #   readiness.idle_reason # => nil: it takes `entry`
  #   readiness.reason      # => nil, or PrintQueue::Reason(code: :offline, message: "Offline")
  #
  #   PrintQueue::Readiness.for(printer) # reads everything for one printer (the console, GraphQL later)
  #
  # The idle reasons, checked in this order (IDLE_REASONS):
  # - :dispatch_paused: the whole queue is paused
  # - :not_taking_jobs: the printer's takes_jobs is off
  # - :offline: no snapshot, or Offline, Connecting or Error
  # - :busy: printing, paused or cancelling, or it has an unfinished printer_jobs row (enqueued or active), old-style
  #   per-printer jobs included: the old queue goes first while the flag is on
  # - :bed_not_cleared: its last print is still on the bed (PR 5's Printer#bed_needs_clearing?)
  # - :nothing_eligible: no entry is eligible for it and fits it (next_job is nil)
  class Readiness < ApplicationModel
    IDLE_REASONS = %i[
      dispatch_paused not_taking_jobs offline busy bed_not_cleared nothing_eligible
    ].freeze #: Array[Symbol]

    attribute :printer
    attribute :status
    # An enqueued or active Printer::Job, of the global queue or the printer's own
    attribute :has_unfinished_job, :boolean, default: false
    attribute :bed_needs_clearing, :boolean, default: false
    attribute :dispatch_paused, :boolean, default: false
    # The PrintQueue::Job that PrintQueue::NextJob found for the printer, nil when none
    attribute :next_job

    # Reads the printer's snapshot (Redis), its unfinished jobs, its bed and the setting, then its next job when it's
    # free for one
    #: (Printer printer) -> PrintQueue::Readiness
    def self.for(printer)
      status = Printer::Status.find_by(printer_id: printer.id)
      dispatch_paused = PrintQueue::Setting.dispatch_paused?
      readiness = new(printer:, status:, dispatch_paused:, bed_needs_clearing: printer.bed_needs_clearing?,
                      has_unfinished_job: printer.jobs.exists?(status: Printer::Job::UNFINISHED_STATUSES))
      readiness.next_job = PrintQueue::NextJob.for(printer, status:, dispatch_paused:).job if readiness.free?
      readiness
    end

    # Why the printer doesn't take a job now, nil when it takes next_job
    #: -> PrintQueue::Reason?
    def reason
      printer_reason || (next_job ? nil : PrintQueue::Reason.new(code: :nothing_eligible, message: 'Nothing to print'))
    end

    # One of IDLE_REASONS, nil when it takes next_job
    #: -> Symbol?
    def idle_reason = reason&.code

    #: -> bool
    def ready? = reason.nil?

    # Whether only the queue keeps it idle (no reason before :nothing_eligible): the dispatcher looks for its next job
    # only then
    #: -> bool
    def free? = printer_reason.nil?

    # @override
    #: -> bool
    def readonly? = true

    private

    # The first idle reason before :nothing_eligible
    #: -> PrintQueue::Reason?
    def printer_reason
      return reason_for(:dispatch_paused, 'Dispatch is paused') if dispatch_paused
      return reason_for(:not_taking_jobs, 'Not taking jobs') unless printer.takes_jobs?

      PrintQueue::Fit.offline_reason(status) || busy_reason ||
        (reason_for(:bed_not_cleared, 'Bed not cleared') if bed_needs_clearing)
    end

    # Connected (Fit.offline_reason is nil) but not idle, or with a job of its own
    #: -> PrintQueue::Reason?
    def busy_reason
      return reason_for(:busy, "Busy: #{status.state_text}") if status.state_family != Printer::StateFamily::Operational

      reason_for(:busy, 'Busy: has a job to finish') if has_unfinished_job
    end

    #: (Symbol code, String message) -> PrintQueue::Reason
    def reason_for(code, message) = PrintQueue::Reason.new(code:, message:)
  end
end
