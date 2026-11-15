# frozen_string_literal: true

class Printer
  class Job < ApplicationRecord
    # Waiting in the queue, and under way. Every other status is finished (completed, error, and later failed).
    UNFINISHED_STATUSES = %w[enqueued active].freeze

    belongs_to :printer, inverse_of: :jobs
    belongs_to :executable, polymorphic: true, inverse_of: :jobs

    validates :status, inclusion: { in: %w[enqueued active completed error] }

    scope :enqueued, -> { where(status: 'enqueued') }
    # The order the spooler starts them in: enqueue time, then id for jobs enqueued together
    scope :in_queue_order, -> { order(created_at: :asc, id: :asc) }
    scope :finished, -> { where.not(status: UNFINISHED_STATUSES) }
    # The last finished first: a finished job isn't written to again, so updated_at is when it finished
    scope :newest_first, -> { order(updated_at: :desc, id: :desc) }
  end
end
