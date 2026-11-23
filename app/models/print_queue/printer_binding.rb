# typed: true
# frozen_string_literal: true

module PrintQueue
  # Prints every copy of an entry on the same printer: binds it to `printer`, or, without one, to the printer its next
  # copy is dispatched to. See PrintQueue::Operation.
  #
  #   PrintQueue::PrinterBinding.new(job:, printer: mk4).save
  #   PrintQueue::PrinterBinding.new(job:).save # bound at its next dispatch
  #
  # The printer must be one the entry may go to (all capable, or listed). Binding usually narrows where the entry can
  # go, so it doesn't ask for a dispatch pass, except when the entry was bound to another printer: the new printer (or
  # any, without one) may take it now.
  class PrinterBinding < EntryOperation
    # The Printer, or nil: bound at its next dispatch
    attribute :printer

    validate :allowed, unless: :refused?

    private

    #: -> String?
    def refusal
      no_longer_queued || printer_not_allowed
    end

    #: -> String?
    def printer_not_allowed
      bound = printer
      return if bound.nil? || job.all_capable? || job.job_printers.exists?(printer_id: bound.id)

      "#{filename} can't go to #{bound.name}"
    end

    # @override
    #: -> void
    def change
      @previous = job.bound_printer
      job.update!(same_printer: true, bound_printer: printer)
    end

    #: -> Array[Printer]
    def pushed_printers = [@previous, printer].compact.uniq

    #: -> bool
    def dispatches?
      previous = @previous
      !previous.nil? && previous != printer
    end
  end
end
