# typed: true
# frozen_string_literal: true

module PrintQueue
  # Changes the number of copies an entry asks for. Never below the copies done or printing (a failed copy can be
  # given up). See PrintQueue::Operation.
  #
  #   change = PrintQueue::CopiesChange.new(job:, copies: 2)
  #   change.save          # => false
  #   change.errors[:base] # => ["Can't go below 3: 2 done and 1 printing"]
  #
  #   PrintQueue::CopiesChange.new(job:, copies: 3, same_printer: true).save # Print More Copies, on one printer
  #
  # `same_printer` (nil: unchanged) keeps every copy on the same printer, or lets them go to any printer again (the
  # batch is unbound, as PrintQueue::PrinterBindingRelease does).
  #
  # Raising the copies of a finished entry prints it again (a Requeue, e.g. to print a failed copy again): it goes back
  # into the queue, at the bottom. Raising the copies, or letting a bound batch go, asks for a dispatch pass; lowering
  # them doesn't.
  class CopiesChange < EntryOperation
    attribute :copies, :integer
    # true or false to change it, nil to keep it
    attribute :same_printer, :boolean

    validates :copies, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validate :allowed, unless: :refused?

    # Why the entry can't ask for this many copies, nil when it can: never below the copies done and printing. Shared
    # with PrintQueue::JobUpdate.
    #: (PrintQueue::Job job, Integer copies) -> String?
    def self.below_floor(job, copies)
      floor = job.done_count + job.printing_count
      return if copies >= floor

      counts = { 'done' => job.done_count, 'printing' => job.printing_count }.select { |_, count| count.positive? }
      "Can't go below #{floor}: #{counts.map { |name, count| "#{count} #{name}" }.join(' and ')}"
    end

    private

    #: -> String?
    def refusal = self.class.below_floor(job, copies.to_i)

    # @override
    #: -> void
    def change
      @raised = copies.to_i > job.copies
      finished = !job.unfinished?
      job.copies = copies
      change_same_printer unless same_printer.nil?
      requeue_at_bottom if finished
      job.save!
    end

    # Off: unbound too. On: bound to the printer it already prints on, if any (PrintQueue::BatchPrinter)
    #: -> void
    def change_same_printer
      @released = job.same_printer? && !same_printer
      @previous = job.bound_printer
      job.bound_printer = batch_printer
      job.same_printer = same_printer
    end

    #: -> Printer?
    def batch_printer
      PrintQueue::BatchPrinter.new(job:, same_printer:, all_capable: job.all_capable?,
                                   printer_ids: job.job_printers.map(&:printer_id), needs: job.needs).printer
    end

    # A finished entry with copies waiting again goes back into the queue, at the bottom
    #: -> void
    def requeue_at_bottom
      job.position = next_position if job.unfinished?
    end

    # The printer it's bound to, or was before it was let go
    #: -> Array[Printer]
    def pushed_printers = [job.bound_printer || @previous].compact

    #: -> bool
    def dispatches? = @raised == true || @released == true
  end
end
