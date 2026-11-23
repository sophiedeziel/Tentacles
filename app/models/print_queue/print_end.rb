# typed: true
# frozen_string_literal: true

module PrintQueue
  # A print event, the print ended handler: the copy's print is over. Its spool records it once it stops monitoring
  # the print (completed, or error when the upload failed). See PrintQueue::CopyOperation.
  #
  #   print_end = PrintQueue::PrintEnd.new(printer_job:, result: 'completed')
  #   print_end.save           # => false when refused
  #   print_end.printer_job    # => status 'completed', finished_at now
  #
  # - The copy ends with the result (RESULTS), and its finished_at. A copy whose cancellation was asked
  #   (PrintQueue::CopyCancellation, cancel_requested_at) ends `cancelled`, whatever the result.
  # - The bed: on a printer that clears its own bed (clears_own_bed), a completed print is cleared now, by the printer
  #   (bed_cleared_by 'automatic'). Any other ended print stays on the bed (Printer#bed_to_clear) until a person
  #   confirms it's cleared (PrintQueue::BedClearance): a print that failed or was cancelled may not have run the
  #   G-code that clears the bed.
  # - Its printer's queue is pushed, then a dispatch pass is asked for: the monitor often sees the printer Operational
  #   before the copy ends, and that pass found the printer busy.
  # Only a copy under way ends: an enqueued copy hasn't started, and a finished copy isn't ended twice.
  class PrintEnd < CopyOperation
    RESULTS = %w[completed error cancelled].freeze #: Array[String]

    # One of RESULTS
    attribute :result, :string

    validates :result, inclusion: { in: RESULTS }
    validate :allowed, unless: :refused?

    private

    #: -> String?
    def refusal
      not_a_copy || case printer_job.status
                    when 'active' then nil
                    when 'enqueued' then "#{copy_name} hasn't started"
                    else "#{copy_name} has already ended"
                    end
    end

    # @override
    #: -> void
    def change
      now = Time.current
      status = printer_job.cancel_requested_at ? 'cancelled' : result
      bed = cleared_by_printer?(status) ? { bed_cleared_at: now, bed_cleared_by: 'automatic' } : {}
      printer_job.update!(status:, finished_at: now, **bed)
    end

    #: (String? status) -> bool
    def cleared_by_printer?(status) = status == 'completed' && printer_job.printer.clears_own_bed?

    #: -> bool
    def dispatches? = true
  end
end
