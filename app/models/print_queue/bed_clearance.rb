# typed: true
# frozen_string_literal: true

module PrintQueue
  # Bed Cleared: a person confirms the last print was taken off the printer's bed, so the printer can take its next
  # copy. See PrintQueue::Operation.
  #
  #   clearance = PrintQueue::BedClearance.new(printer:)
  #   clearance.save          # => false when refused
  #   clearance.errors[:base] # => ['Nothing to clear on Prusa MK4']
  #   clearance.printer_job   # => the print cleared (bed_cleared_at now, bed_cleared_by 'person')
  #
  # The print on the bed is Printer#bed_to_clear: refused when there's none. Its printer's queue is pushed, then a
  # dispatch pass is asked for.
  class BedClearance < Operation
    attribute :printer

    validates :printer, presence: true
    validate :allowed, unless: :refused?

    # The print whose bed was cleared (a Printer::Job), after save
    #: Printer::Job?
    attr_reader :printer_job

    private

    #: -> String?
    def refusal
      "Nothing to clear on #{printer.name}" unless printer.bed_needs_clearing?
    end

    # @override
    #: -> void
    def change
      @printer_job = printer.bed_to_clear
      T.must(@printer_job).update!(bed_cleared_at: Time.current, bed_cleared_by: 'person')
    end

    #: -> Array[Printer]
    def pushed_printers = [printer]

    #: -> bool
    def dispatches? = true
  end
end
