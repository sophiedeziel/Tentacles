# typed: true
# frozen_string_literal: true

module PrintQueue
  # Lets the copies of an entry go to any printer again (undoes PrintQueue::PrinterBinding): same_printer off, unbound.
  # See PrintQueue::Operation.
  #
  #   PrintQueue::PrinterBindingRelease.new(job:).save
  #
  # Asks for a dispatch pass: printers other than the bound one may take it now.
  class PrinterBindingRelease < EntryOperation
    validate :allowed, unless: :refused?

    private

    #: -> String?
    def refusal = no_longer_queued

    # @override
    #: -> void
    def change
      @previous = job.bound_printer
      job.update!(same_printer: false, bound_printer: nil)
    end

    #: -> Array[Printer]
    def pushed_printers = [@previous].compact

    #: -> bool
    def dispatches? = true
  end
end
