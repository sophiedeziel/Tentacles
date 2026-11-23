# typed: true
# frozen_string_literal: true

module PrintQueue
  # The printer a same-printer batch is bound to once its options change (PrintQueue::CopiesChange,
  # PrintQueue::JobUpdate), and as the Edit page's summary shows it (PrintQueue::Estimate): one rule, so the summary
  # agrees with what saving does. Read-only.
  #
  #   PrintQueue::BatchPrinter.new(job:, same_printer: true, all_capable: true).printer # => mk4
  #
  # nil when same_printer is off, or when no printer qualifies: the dispatcher then binds the batch to the printer
  # that takes its next copy. Otherwise, the first of these that the batch may still go to:
  #
  # 1. the printer it's bound to (same_printer was on);
  # 2. the printer of its latest copy started (highest copy number) that is printing, handed over or done: a copy
  #    already printing or printed on a printer keeps the batch there when same_printer goes on. Failed and cancelled
  #    copies don't count.
  #
  # "May still go to": allowed by its printer list (all capable, or listed in `printer_ids`). A printer that no longer
  # is lets the batch go.
  class BatchPrinter < ApplicationModel
    # The statuses of the copies that tie a batch to their printer
    STARTED_STATUSES = [*Printer::Job::UNFINISHED_STATUSES, 'completed'].freeze #: Array[String]

    # The PrintQueue::Job, as saved before the change
    attribute :job
    attribute :same_printer, :boolean, default: false
    attribute :all_capable, :boolean, default: true
    # Printer ids (Integers or Strings), when all_capable is off. Ignored otherwise
    attribute :printer_ids, default: -> { [] }

    # The printer it's bound to after the change, nil when it isn't (see above)
    #: -> Printer?
    def printer
      return unless same_printer

      [bound_printer, started_printer].compact.find { |candidate| may_go_to?(candidate) }
    end

    # @override
    #: -> bool
    def readonly? = true

    private

    #: -> Printer?
    def bound_printer = (job.bound_printer if job.same_printer?)

    # The printer of its latest copy printing, handed over or done
    #: -> Printer?
    def started_printer
      return if job.new_record?

      job.printer_jobs.where(status: STARTED_STATUSES).order(copy_number: :desc, id: :desc).first&.printer
    end

    #: (Printer candidate) -> bool
    def may_go_to?(candidate)
      all_capable || listed_ids.include?(candidate.id.to_s)
    end

    #: -> Array[String]
    def listed_ids = Array(printer_ids).compact_blank.map(&:to_s)
  end
end
