# frozen_string_literal: true

class Printer
  # A job of a printer: a file to print on it, enqueued the old way (on the printer's own queue), or a copy of a global
  # queue entry (`print_job`, with its `copy_number`, the `filament` loaded when it was dispatched and its bed state).
  class Job < ApplicationRecord
    STATUSES = %w[enqueued active completed error cancelled].freeze
    # Waiting in the queue, and under way. Every other status is finished (completed, error, cancelled).
    UNFINISHED_STATUSES = %w[enqueued active].freeze

    belongs_to :printer, inverse_of: :jobs
    belongs_to :executable, polymorphic: true, inverse_of: :jobs
    # The global queue entry this job is a copy of: nil for a job enqueued on the printer's own queue
    belongs_to :print_job, class_name: 'PrintQueue::Job', optional: true, inverse_of: :printer_jobs

    # Who confirmed the bed was cleared after the print: a person (Bed Cleared), or the printer itself (clears_own_bed)
    enum :bed_cleared_by, { person: 'person', automatic: 'automatic' }, prefix: true, validate: { allow_nil: true }

    validates :status, inclusion: { in: STATUSES }

    scope :enqueued, -> { where(status: 'enqueued') }
    # The order the spooler starts them in: enqueue time, then id for jobs enqueued together
    scope :in_queue_order, -> { order(created_at: :asc, id: :asc) }
    scope :finished, -> { where.not(status: UNFINISHED_STATUSES) }
    # The last finished first: a finished job isn't written to again, so updated_at is when it finished
    scope :newest_first, -> { order(updated_at: :desc, id: :desc) }

    # Queue widgets follow the queue through printQueueChanged. The spooler writes progress twice a second, so only
    # what changes a queue pushes: a new job, a removed one, a new status. Whoever writes that change pushes it, once
    # it's committed (once per printer for several jobs written together):
    #
    #   job.update!(status: 'active')
    #   job.push_print_queue_changed
    #
    # The job is saved by then: a push that fails is logged, never raised, and only leaves the dashboards behind until
    # their next reload.
    def push_print_queue_changed
      return unless printer

      TentaclesSchema.subscriptions.trigger(:print_queue_changed, {}, printer)
    rescue StandardError => e
      Rails.logger.error("[Printer::Job] Could not push printQueueChanged: #{e.class}: #{e.message}")
    end
  end
end
