# typed: true
# frozen_string_literal: true

module PrintQueue
  # Bed Cleared: a person confirms the print they saw on the printer's bed was taken off it, so the printer can take
  # its next copy. See PrintQueue::Operation.
  #
  #   clearance = PrintQueue::BedClearance.new(printer:, expected_print_id: print.id)
  #   clearance.save          # => false when refused
  #   clearance.errors[:base] # => ["Prusa MK4's bed now holds another print: bracket.gcode, copy 3 of 10. Check it
  #                           #     before clearing the bed."]
  #   clearance.printer_job   # => the print cleared (bed_cleared_at now, bed_cleared_by 'person')
  #
  # The print on the bed is Printer#bed_to_clear. `expected_print_id` is the one the person was shown (a Printer::Job
  # id): refused when the bed holds another one (theirs was cleared, then a newer print finished while they looked),
  # or nothing. Checked again under the queue's lock, so a print that finishes meanwhile is never cleared unseen. Its
  # printer's queue is pushed, then a dispatch pass is asked for.
  class BedClearance < Operation
    attribute :printer
    attribute :expected_print_id, :big_integer

    validates :printer, :expected_print_id, presence: true
    validate :allowed, unless: :refused?

    # The print whose bed was cleared (a Printer::Job), after save
    #: Printer::Job?
    attr_reader :printer_job

    private

    #: -> String?
    def refusal
      on_bed = printer.bed_to_clear
      return "Nothing to clear on #{printer.name}" unless on_bed

      another_print(on_bed) unless on_bed.id == expected_print_id
    end

    # "Prusa MK4's bed now holds another print: bracket.gcode, copy 3 of 10. Check it before clearing the bed."
    #: (Printer::Job on_bed) -> String
    def another_print(on_bed)
      entry = T.must(on_bed.print_job)
      print = T.must(entry.item).filename
      print += ", copy #{on_bed.copy_number} of #{entry.copies}" if entry.copies > 1
      "#{printer.name}'s bed now holds another print: #{print}. Check it before clearing the bed."
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
