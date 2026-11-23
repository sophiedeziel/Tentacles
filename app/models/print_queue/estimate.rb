# typed: true
# frozen_string_literal: true

module PrintQueue
  # An entry as the Add to Queue form (or the Edit page) describes it, not saved: how each printer fits it, what the
  # queue holds now, the filament and print time of its copies and what happens to it first. Read-only: it writes
  # nothing, and reuses the rules the dispatcher reads (PrintQueue::Needs, PrintQueue::Fit, PrintQueue::Forecast), so
  # the form agrees with what the queue will do once it's saved.
  #
  #   estimate = PrintQueue::Estimate.new(item:, copies: 10, material: 'PLA', colour: 'Black')
  #   estimate.fits          # => one PrintQueue::Fit per printer, by id
  #   estimate.jobs_ahead    # => 5: the entries with copies waiting that go before it
  #   estimate.prints_ahead  # => 15: their copies waiting
  #   estimate.print_seconds # => 42000: the summary's time × the copies to print, nil when Not known
  #   estimate.starts        # => PrintQueue::Forecast::Outcome(kind: :after_current_print, printer: mk4, ...)
  #
  # Editing an entry (`job`): it keeps its place (`position` is ignored), the form replaces it in the queue, and only
  # its copies still to start are counted (copies done, printing or failed are not printed again).
  #
  # When it starts is a kind of What Happens Next, without a time: the time comes with the queue simulation.
  class Estimate < ApplicationModel
    # The filament of one tool, for all the copies to print: grams and mm nil when Not known
    class FilamentUse < ApplicationModel
      attribute :tool, :integer
      attribute :material, :string
      attribute :colour, :string
      attribute :grams, :decimal
      attribute :millimetres, :decimal

      # @override
      #: -> bool
      def readonly? = true
    end

    # The Library::Item to print (the entry's, when editing one)
    attribute :item
    attribute :copies, :integer, default: 1
    # The material asked for (a key of Filament::MATERIALS), nil for the one its G-code says
    attribute :material, :string
    # The colour asked for, nil for Any colour
    attribute :colour, :string
    attribute :same_printer, :boolean, default: false
    # "All that can print it". When off, only on `printer_ids`
    attribute :all_capable, :boolean, default: true
    attribute :printer_ids, default: -> { [] }
    # 'bottom' or 'top' (ignored when editing)
    attribute :position, :string, default: 'bottom'
    attribute :held, :boolean, default: false
    # The PrintQueue::Job edited, nil when adding one
    attribute :job
    attribute :fleet, default: -> { PrintQueue::Fleet.current }
    # Array[PrintQueue::Job]: the unfinished entries, their copy counts preset (PrintQueue::NextJob.candidates)
    attribute :entries, default: -> { PrintQueue::NextJob.candidates }

    # A key of Filament::MATERIALS ("pla" is "PLA"), nil when blank
    #: (untyped value) -> void
    def material=(value)
      super(Filament.material_key(value).presence)
    end

    # How each printer fits it, by printer id: PrintQueue::Fit with its needs, whatever its printer list
    #: -> Array[PrintQueue::Fit]
    def fits
      fleet.printers.map { |printer| PrintQueue::Fit.new(needs:, printer:, status: fleet.status(printer)) }
    end

    #: -> PrintQueue::Needs
    def needs
      @needs ||= draft.needs
    end

    # The copies handed to a printer and not ended, in the whole queue
    #: -> Integer
    def printing_count = Printer::Job.copies.unfinished.count

    # The entries with copies waiting now (the one edited included)
    #: -> Integer
    def waiting_jobs = entries.count { |entry| entry.waiting_count.positive? }

    # The entries with copies waiting that go before it
    #: -> Integer
    def jobs_ahead = ahead.size

    # The copies waiting of the entries that go before it
    #: -> Integer
    def prints_ahead = ahead.sum(&:waiting_count)

    # The copies it will print: the copies asked for, less those done, printing or failed when editing
    #: -> Integer
    def copies_to_print = draft.waiting_count

    # One per tool it needs, in tool order: the material asked for (or the G-code's), the colour asked for, and the
    # summary's amounts × the copies to print. Empty when no tool is known.
    #: -> Array[PrintQueue::Estimate::FilamentUse]
    def filaments
      read = summary&.tools.to_a
      needs.tools.map do |needed|
        amounts = read.find { |tool| tool.tool == needed.tool }
        FilamentUse.new(tool: needed.tool, material: needed.material, colour:, **totals_of(amounts))
      end
    end

    # The filament of every copy to print, nil when Not known
    #: -> BigDecimal?
    def filament_grams = times_copies(summary&.filament_grams)

    #: -> BigDecimal?
    def filament_millimetres = times_copies(summary&.filament_millimetres)

    # The print time of every copy to print, one after another, in seconds: nil when Not known
    #: -> Integer?
    def print_seconds = times_copies(summary&.print_seconds)&.to_i

    # What happens to it first (PrintQueue::Forecast), as if it were in the queue: nil when no copy is left to start
    #: -> PrintQueue::Forecast::Outcome?
    def starts
      PrintQueue::Forecast.current(fleet:, entries: [*others, draft]).outcome(draft)
    end

    # @override
    #: -> bool
    def readonly? = true

    private

    # The entry as the form describes it, not saved: the edited entry's id, place, binding and counts when editing
    #: -> PrintQueue::Job
    def draft
      @draft ||= begin
        entry = PrintQueue::Job.new(item:, copies:, material:, colour:, same_printer:, all_capable:, held:,
                                    position: draft_position)
        edited(entry) if job
        printer_ids_listed.each { |printer_id| entry.job_printers.build(printer_id:) } unless all_capable
        entry
      end
    end

    #: (PrintQueue::Job entry) -> void
    def edited(entry)
      edited = job #: as !nil
      entry.id = edited.id
      entry.bound_printer_id = edited.bound_printer_id if same_printer
      entry.copy_counts = edited.copy_counts
    end

    # Its place: the edited entry's, else first or last among the entries still in the queue
    #: -> Integer
    def draft_position
      return job.position if job

      positions = others.map(&:position)
      position == 'top' ? (positions.min || 1) - 1 : (positions.max || 0) + 1
    end

    # The entries still in the queue, but the one edited
    #: -> Array[PrintQueue::Job]
    def others
      @others ||= entries.reject { |entry| job && entry.id == job.id }
    end

    # The others with copies waiting that go before it, in queue order
    #: -> Array[PrintQueue::Job]
    def ahead
      @ahead ||= others.select { |entry| entry.waiting_count.positive? && before_it?(entry) }
    end

    # In queue order (position, then id): a new entry goes after the others of its position
    #: (PrintQueue::Job entry) -> bool
    def before_it?(entry)
      return entry.position < draft.position unless entry.position == draft.position

      draft.id.nil? || entry.id < draft.id
    end

    #: -> Array[Integer]
    def printer_ids_listed = Array(printer_ids).compact_blank.map(&:to_i).uniq

    # The summary of its file, when it was read
    #: -> Library::GcodeSummary?
    def summary
      @summary ||= item&.gcode_summary&.then { |read| read if read.ready? }
    end

    # A tool's grams and mm, × the copies to print
    #: (Library::GcodeSummary::Tool? tool) -> Hash[Symbol, BigDecimal?]
    def totals_of(tool) = { grams: times_copies(tool&.grams), millimetres: times_copies(tool&.millimetres) }

    #: (Numeric? value) -> BigDecimal?
    def times_copies(value) = (BigDecimal(value.to_s) * copies_to_print unless value.nil?)
  end
end
