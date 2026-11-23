# typed: true
# frozen_string_literal: true

module PrintQueue
  # The printers as the global queue sees them, read once for all of them: each printer (with its loaded filaments),
  # its Printer::Status snapshot, whether it has an unfinished printer_jobs row and whether its bed needs clearing.
  # Read-only, like the rules it feeds: the queue page's printer sections, PrintQueue::Forecast and the printers that
  # can print an entry all read the same load.
  #
  #   fleet = PrintQueue::Fleet.current # 4 queries and one Redis MGET, whatever the number of printers
  #   fleet.available          # => the printers that take jobs and are free for one
  #   fleet.bed_to_clear       # => the printers whose last print is still on the bed
  #   fleet.readiness(printer) # => its PrintQueue::Readiness, dispatch pause aside
  #   fleet.capable(entry)     # => the printers that can print the entry
  class Fleet < ApplicationModel
    # Array[Printer], by id, their loaded_filaments loaded
    attribute :printers, default: -> { [] }
    # Hash[Integer, Printer::Status], by printer id: a printer without a snapshot is left out
    attribute :statuses, default: -> { {} }
    # Set[Integer]: the printers with an enqueued or active printer_jobs row, of the queue or their own
    attribute :busy_ids, default: -> { Set.new }
    # Set[Integer]: the printers whose bed needs clearing (Printer.ids_with_bed_to_clear)
    attribute :bed_to_clear_ids, default: -> { Set.new }

    # Every printer, read now. A Redis error leaves the snapshots out: every printer is offline for the queue.
    #: -> PrintQueue::Fleet
    def self.current
      printers = ::Printer.order(:id).includes(:loaded_filaments).to_a
      ids = printers.map(&:id)
      new(printers:, statuses: statuses_of(ids), bed_to_clear_ids: ::Printer.ids_with_bed_to_clear(ids),
          busy_ids: Printer::Job.where(printer_id: ids, status: Printer::Job::UNFINISHED_STATUSES)
                                .distinct.pluck(:printer_id).to_set)
    end

    #: (Array[Integer] ids) -> Hash[Integer, Printer::Status]
    def self.statuses_of(ids)
      Printer::Status.where(printer_id: ids).index_by(&:printer_id)
    rescue Redis::BaseError => e
      Rails.logger.warn("[PrintQueue::Fleet] Could not read the printer statuses: #{e.message}")
      {}
    end
    private_class_method :statuses_of

    # The printer with this id, nil when there is none (or no id)
    #: (Integer? id) -> Printer?
    def printer(id) = (printers.find { |printer| printer.id == id } if id)

    #: (Printer printer) -> Printer::Status?
    def status(printer) = statuses[printer.id]

    # Why the printer would or wouldn't take a job, dispatch pause aside (the page shows the pause on its own): its
    # PrintQueue::Readiness without a next job, so `free?` is whether only the queue keeps it idle
    #: (Printer printer) -> PrintQueue::Readiness
    def readiness(printer)
      @readinesses ||= {} #: Hash[Integer, PrintQueue::Readiness]?
      @readinesses[printer.id] ||= PrintQueue::Readiness.new(
        printer:, status: status(printer), dispatch_paused: false, has_unfinished_job: busy_ids.include?(printer.id),
        bed_needs_clearing: bed_to_clear_ids.include?(printer.id)
      )
    end

    # The printers that take jobs and are free for one: connected, idle (Operational), without an unfinished job and
    # with a clear bed. Whether an entry fits them, and whether dispatch is paused, aside.
    #: -> Array[Printer]
    def available = printers.select { |printer| readiness(printer).free? }

    # The printers whose last print is still on the bed, whether they take jobs or not
    #: -> Array[Printer]
    def bed_to_clear = printers.select { |printer| bed_to_clear_ids.include?(printer.id) }

    # The printers that can print the entry: open to it (PrintQueue::Job#open_to?: allowed by its printer list, not
    # bound to another printer) and without a hard limitation for it (PrintQueue::HardLimitations: not :cannot).
    # Whether they take jobs, are online or have its filament loaded, aside. Preload the entry's job_printers and its
    # item's summary for many.
    #: (PrintQueue::Job entry, ?needs: PrintQueue::Needs) -> Array[Printer]
    def capable(entry, needs: entry.needs)
      printers.select do |printer|
        entry.open_to?(printer) && PrintQueue::HardLimitations.new(needs:, printer:).none?
      end
    end

    # Read once: nothing to save
    # @override
    #: -> bool
    def readonly? = true
  end
end
