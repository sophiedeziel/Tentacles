# typed: true
# frozen_string_literal: true

module PrintQueue
  # One entry of the global queue: a file (`item`) and the number of `copies` to print. Each copy the dispatcher
  # starts is a Printer::Job (`printer_jobs`, with its `copy_number`); the entry's counts are read from them:
  #
  #   job.copies          # => 5, as asked
  #   job.done_count      # => 2: completed
  #   job.printing_count  # => 1: enqueued on a printer or under way
  #   job.failed_count    # => 1: ended in error or cancelled. It uses up its copy without being done, and isn't
  #                       #    retried: printing it again is a manual Requeue (raising `copies`)
  #   job.waiting_count   # => 1: still to dispatch
  #   job.unfinished?     # => true: waiting or printing copies, so the entry is in the queue
  #
  # The counts are read once per entry and kept until `reload`. For many entries, read them in one query:
  #
  #   counts = PrintQueue::Job.copy_counts(jobs.map(&:id)) # => { 12 => { done: 2, printing: 1, failed: 1 }, ... }
  #   jobs.each { |job| job.copy_counts = counts.fetch(job.id) }
  #
  # `colour` is the colour the entry asks for (nil: Any colour); the material comes from the file's G-code summary.
  # Phase 4's GraphQL calls this a PrintJob.
  class Job < ApplicationRecord
    self.table_name = 'print_jobs'

    # The Printer::Job statuses each count is made of. Every status is in one of them.
    COPY_STATUSES = {
      done: %w[completed],
      printing: Printer::Job::UNFINISHED_STATUSES,
      failed: %w[error cancelled]
    }.freeze #: Hash[Symbol, Array[String]]

    belongs_to :item, class_name: 'Library::Item', foreign_key: :file_record_id, inverse_of: :print_jobs
    # The printer a same-printer batch is bound to: nil until its first copy is dispatched (or after release)
    belongs_to :bound_printer, class_name: '::Printer', optional: true
    # The printers it's limited to, when all_capable is off. delete_all: the database cascades too
    has_many :job_printers, class_name: 'PrintQueue::JobPrinter', foreign_key: :print_job_id, inverse_of: :job,
                            dependent: :delete_all
    has_many :printers, through: :job_printers
    # Its copies. Not `copies`, the number asked for. The database nullifies print_job_id if an entry is deleted
    has_many :printer_jobs, class_name: 'Printer::Job', foreign_key: :print_job_id, inverse_of: :print_job,
                            dependent: nil

    normalizes :colour, with: ->(value) { value.squish.presence }

    validates :copies, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :position, presence: true
    validates :colour, length: { maximum: 40 }

    scope :in_queue_order, -> { order(position: :asc, id: :asc) }
    # The entries still in the queue: a copy printing, or more copies asked than have finished (see #unfinished?)
    scope :unfinished, lambda {
      copies = Printer::Job.where(Printer::Job.arel_table[:print_job_id].eq(arel_table[:id]))
      finished = copies.finished.select(Arel.star.count)
      where(arel_table[:copies].gt(finished.arel))
        .or(where(copies.where(status: Printer::Job::UNFINISHED_STATUSES).arel.exists))
    }

    # The copy counts of these entries, in one grouped query: zeros for an entry without copies
    #
    #   PrintQueue::Job.copy_counts([12, 13]) # => { 12 => { done: 2, printing: 1, failed: 1 }, 13 => { done: 0, ... } }
    #: (Array[Integer] ids) -> Hash[Integer, Hash[Symbol, Integer]]
    def self.copy_counts(ids)
      by_status = Printer::Job.where(print_job_id: ids).group(:print_job_id, :status).count
      ids.index_with do |id|
        COPY_STATUSES.transform_values { |statuses| statuses.sum { |status| by_status.fetch([id, status], 0) } }
      end
    end

    # Keeps the matching key beside the colour (a writer, not a callback: see app/models/README.md)
    #: (untyped value) -> void
    def colour=(value)
      super
      self.colour_key = colour && Filament.colour_key(colour)
    end

    # { done:, printing:, failed: }, read once (see .copy_counts) and kept until #reload
    #: -> Hash[Symbol, Integer]
    def copy_counts
      @copy_counts ||= new_record? ? COPY_STATUSES.transform_values { 0 } : self.class.copy_counts([id]).fetch(id)
    end

    # Presets the counts read for many entries by .copy_counts
    #: Hash[Symbol, Integer]
    attr_writer :copy_counts

    #: -> Integer
    def done_count = copy_counts.fetch(:done)

    #: -> Integer
    def printing_count = copy_counts.fetch(:printing)

    #: -> Integer
    def failed_count = copy_counts.fetch(:failed)

    # The copies still to dispatch: 0 once every copy asked for is done, printing or failed (a failed copy isn't
    # dispatched again)
    #: -> Integer
    def waiting_count = [copies - done_count - printing_count - failed_count, 0].max

    # Whether the entry is still in the queue: copies waiting or printing (the .unfinished scope in SQL)
    #: -> bool
    def unfinished? = (waiting_count + printing_count).positive?

    # What it needs from a printer, read from its file's G-code summary each time (see PrintQueue::Needs)
    #: -> PrintQueue::Needs
    def needs = PrintQueue::Needs.of(self)

    # Whether the printer may take a copy of it, before its fit: allowed on it (all_capable, or listed in job_printers,
    # read from the loaded rows when preloaded) and not a same-printer batch bound to another printer (bound to this
    # one, or not bound yet, is fine). bound_printer_id is ignored when same_printer is off.
    #: (Printer printer) -> bool
    def open_to?(printer)
      allowed = all_capable? || job_printers.any? { |job_printer| job_printer.printer_id == printer.id }
      allowed && (!same_printer? || bound_printer_id.nil? || bound_printer_id == printer.id)
    end

    # The copy_number of the next copy dispatched: 1 for the first
    #: -> Integer
    def next_copy_number = (printer_jobs.maximum(:copy_number) || 0) + 1

    #: (?untyped options) -> self
    def reload(options = nil)
      @copy_counts = nil
      super
    end
  end
end
