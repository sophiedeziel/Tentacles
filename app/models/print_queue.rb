# typed: strict
# frozen_string_literal: true

# The global print queue's domain (#2934): entries that belong to the queue, not to a printer. Each entry
# (PrintQueue::Job) is a file and a number of copies, and each copy it dispatches is a Printer::Job of the printer that
# prints it. Built behind the global_print_queue flag: with it off, nothing here runs.
#
#   PrintQueue.enabled?                          # => false unless GLOBAL_PRINT_QUEUE is "true" or "1"
#   PrintQueue::Job.unfinished.in_queue_order    # the entries still in the queue
#   PrintQueue::Setting.dispatch_paused?         # the fleet-level pause
#
# The rules, read-only and computed from their inputs: PrintQueue::Needs (what an entry needs, from its file's G-code
# summary), PrintQueue::HardLimitations and PrintQueue::Fit (how an entry fits a printer, and why),
# PrintQueue::NextJob (the entry a printer prints next) and PrintQueue::Readiness (why a printer is idle):
#
#   PrintQueue::NextJob.for(printer).job             # => a PrintQueue::Job, or nil
#   PrintQueue::Readiness.for(printer).idle_reason   # => nil, or :offline, :busy, :nothing_eligible, ...
#
# For the queue page (GraphQL's globalQueue), PrintQueue::Fleet reads every printer with what the rules need at once,
# and PrintQueue::Forecast says what happens next to each entry (What Happens Next), agreeing with the dispatcher:
#
#   PrintQueue::Forecast.current.outcome(entry) # => PrintQueue::Forecast::Outcome(kind: :after_current_print, ...)
#
# The operations change the queue (see PrintQueue::Operation): PrintQueue::Addition, Move, Hold, Release,
# CopiesChange, WaitingCopiesRemoval, PrinterBinding, PrinterBindingRelease, DispatchPause, DispatchResumption and
# CopyCancellation. Each pushes PrintQueue.push_changed once, then asks for a dispatch pass (PrintQueue::DispatchRequest)
# when it can make a printer eligible:
#
#   addition = PrintQueue::Addition.new(item:, copies: 3)
#   addition.save # => false, with errors[:base], when refused
#
# The dispatcher (PrintQueue::Dispatch) gives each ready printer its next entry, in one pass that the spooler runs on
# a dispatch request and every SWEEP_INTERVAL (PrintQueue::Sweep). The copies it creates are started through
# PrintQueue.connector:
#
#   dispatch = PrintQueue::Dispatch.new
#   dispatch.save!
#   dispatch.dispatched # => the Printer::Jobs created
#
# The tables are print_jobs, print_job_printers and print_queue_settings (each model sets its table_name).
module PrintQueue
  # How often the spooler sweeps the queue (PrintQueue::Sweep): a dispatch pass, then the idle spools whose printer
  # has an enqueued copy are started. It catches up on what a lost or ignored Redis message left behind.
  SWEEP_INTERVAL = 30.seconds #: ActiveSupport::Duration

  # Whether the global queue is on (config.x.global_print_queue, from GLOBAL_PRINT_QUEUE). Specs stub this.
  #: -> bool
  def self.enabled? = Rails.configuration.x.global_print_queue == true

  # How the queue starts, pauses, resumes and cancels copies on the printers (see PrintQueue::Connector):
  # PrintQueue::Connector::Spooler unless another one was set (PrintQueue.connector=).
  #: -> PrintQueue::Connector
  def self.connector
    @connector ||= PrintQueue::Connector::Spooler.new #: PrintQueue::Connector?
  end

  # Swaps the connector, for this process: nil goes back to the default. The scenario specs and the console set a
  # PrintQueue::Connector::Fake (spec/rails_helper.rb resets it after each example).
  #
  #   PrintQueue.connector = PrintQueue::Connector::Fake.new
  #
  # Process-wide, not per thread: the passes that start copies run on other threads than the one that set it (the
  # spooler's main thread on a dispatch request, its sweep thread, a spool thread in the scenario specs), and they
  # must all use it. Setting it is a single reference write; it's swapped between examples, not while copies
  # dispatch. In the console it only changes that process: a spooler running elsewhere keeps its own.
  #: (PrintQueue::Connector? connector) -> void
  def self.connector=(connector)
    @connector = connector
  end

  # Pushes printQueueChanged for each printer whose queue changed, once a queue change is committed. Phase 4 adds the
  # fleet-level subscription (the whole queue) here, so every queue operation keeps calling this one method.
  #
  # Best effort, like Printer::Job#push_print_queue_changed: a push that fails is logged, never raised, and the next
  # printers are still pushed.
  #
  #   PrintQueue.push_changed([printer])
  #: (?Array[Printer] printers) -> void
  def self.push_changed(printers = [])
    printers.uniq.each do |printer|
      TentaclesSchema.subscriptions.trigger(:print_queue_changed, {}, printer)
    rescue StandardError => e
      Rails.logger.error("[PrintQueue] Could not push printQueueChanged for printer #{printer.id}: " \
                         "#{e.class}: #{e.message}")
    end
  end
end
