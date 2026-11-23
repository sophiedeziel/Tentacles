# typed: true
# frozen_string_literal: true

module PrintQueue
  # One dispatch pass: every printer that is ready for the global queue gets a copy of its next entry
  # (PrintQueue::NextJob), as an enqueued Printer::Job its spool starts. The spooler runs it on a dispatch request
  # (PrintQueue::DispatchRequest) and every SWEEP_INTERVAL (PrintQueue::Sweep).
  #
  #   dispatch = PrintQueue::Dispatch.new
  #   dispatch.save!      # => true. Does nothing while the global queue is off
  #   dispatch.dispatched # => [#<Printer::Job printer_id: 1, print_job_id: 4, copy_number: 2, status: "enqueued">]
  #
  # In one transaction, under the queue's lock:
  # 1. the settings row (PrintQueue::Setting.lock_current, the lock the queue operations take): passes and operations
  #    run one at a time. Nothing is dispatched while dispatch is paused.
  # 2. the printers that take jobs, by id, FOR UPDATE, with their loaded filaments
  # 3. the unfinished entries, in position order, FOR UPDATE, with their copy counts (PrintQueue::NextJob.candidates)
  # 4. the printers' snapshots (one Redis MGET), which of them have an unfinished printer_jobs row (one query) and
  #    which of them have a print on their bed (Printer.ids_with_bed_to_clear, one query)
  # 5. for each printer that is free (PrintQueue::Readiness), its next entry: a copy is created, the entry is bound to
  #    it when it's an unbound same-printer batch, and the copy counts as printing for the printers after it. A printer
  #    gets one copy per pass.
  # After the commit, each copy is started (PrintQueue.connector) and PrintQueue.push_changed is called once with the
  # printers that got one.
  class Dispatch < ApplicationModel
    # The copies created (Printer::Jobs, enqueued), after save
    #: -> Array[Printer::Job]
    def dispatched = @dispatched || []

    private

    #: -> void
    def persist
      return unless PrintQueue.enabled?

      @copy_numbers = {} #: Hash[Integer, Integer]?
      @dispatched = ApplicationRecord.transaction { dispatch } #: Array[Printer::Job]?
      return if dispatched.empty?

      dispatched.each { |copy| PrintQueue.connector.start(copy) }
      PrintQueue.push_changed(dispatched.map { |copy| T.must(copy.printer) })
    end

    # The pass, inside the transaction
    #: -> Array[Printer::Job]
    def dispatch
      # First: the reads below see what the previous holder of the lock committed
      return [] if PrintQueue::Setting.lock_current.dispatch_paused?

      printers = ::Printer.where(takes_jobs: true).order(:id).lock.includes(:loaded_filaments).to_a
      return [] if printers.empty?

      entries = PrintQueue::NextJob.candidates(PrintQueue::Job.lock)
      entries.empty? ? [] : assign(printers, entries)
    end

    # Gives each free printer, in id order, a copy of its next entry
    #: (Array[Printer] printers, Array[PrintQueue::Job] entries) -> Array[Printer::Job]
    def assign(printers, entries)
      readinesses(printers).filter_map do |readiness|
        entry = next_entry(readiness, entries)
        copy_of(entry, readiness.printer) if entry
      end
    end

    # Each printer's readiness, from what is read once for all of them: their snapshots, which of them are busy and
    # which of them have a print on their bed
    #: (Array[Printer] printers) -> Array[PrintQueue::Readiness]
    def readinesses(printers)
      ids = printers.map(&:id)
      statuses = Printer::Status.where(printer_id: ids).index_by(&:printer_id)
      busy = busy_printer_ids(ids)
      bed_to_clear = ::Printer.ids_with_bed_to_clear(ids)
      printers.map do |printer|
        PrintQueue::Readiness.new(printer:, status: statuses[printer.id], dispatch_paused: false,
                                  has_unfinished_job: busy.include?(printer.id),
                                  bed_needs_clearing: bed_to_clear.include?(printer.id))
      end
    end

    # The printer's next entry, when it's free for one
    #: (PrintQueue::Readiness readiness, Array[PrintQueue::Job] entries) -> PrintQueue::Job?
    def next_entry(readiness, entries)
      return unless readiness.free?

      PrintQueue::NextJob.new(printer: readiness.printer, status: readiness.status, entries:,
                              dispatch_paused: false).job
    end

    # The printers with an enqueued or active job, of the queue or their own: one query
    #: (Array[Integer] printer_ids) -> Set[Integer]
    def busy_printer_ids(printer_ids)
      Printer::Job.where(printer_id: printer_ids, status: Printer::Job::UNFINISHED_STATUSES)
                  .distinct.pluck(:printer_id).to_set
    end

    # Creates the entry's next copy on the printer
    #: (PrintQueue::Job entry, Printer printer) -> Printer::Job
    def copy_of(entry, printer)
      item = T.must(entry.item)
      copy = printer.jobs.create!(
        status: 'enqueued', executable: item, name: item.filename, print_job: entry,
        copy_number: next_copy_number(entry), filament: filament_snapshot(printer)
      )
      # The copy is printing: a printer after this one doesn't take a copy that isn't there
      entry.copy_counts = entry.copy_counts.merge(printing: entry.printing_count + 1)
      entry.update!(bound_printer: printer) if entry.same_printer? && entry.bound_printer_id.nil?
      copy
    end

    # Counted here: two copies of one entry in a pass get distinct numbers
    #: (PrintQueue::Job entry) -> Integer
    def next_copy_number(entry)
      @copy_numbers ||= {}
      @copy_numbers[entry.id] = @copy_numbers[entry.id]&.succ || entry.next_copy_number
    end

    # The filament loaded in each slot when the copy was dispatched
    #: (Printer printer) -> Array[Hash[String, untyped]]
    def filament_snapshot(printer)
      printer.loaded_filaments.sort_by(&:slot).map do |filament|
        { 'slot' => filament.slot, 'material' => filament.material, 'colour' => filament.colour }
      end
    end
  end
end
