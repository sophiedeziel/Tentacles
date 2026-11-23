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
# The tables are print_jobs, print_job_printers and print_queue_settings (each model sets its table_name).
module PrintQueue
  # Whether the global queue is on (config.x.global_print_queue, from GLOBAL_PRINT_QUEUE). Specs stub this.
  #: -> bool
  def self.enabled? = Rails.configuration.x.global_print_queue == true

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
