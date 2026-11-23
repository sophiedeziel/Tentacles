# typed: true
# frozen_string_literal: true

module PrintQueue
  class Connector
    # A connector without printers: the global queue runs whole in the scenario specs and in the console, with the
    # printers' side played by hand.
    #
    # In: the commands the queue sends are recorded, and pause, resume and cancel are accepted (or refused with
    # `refusal`). Nothing reaches a printer.
    #
    #   fake = PrintQueue::Connector::Fake.new
    #   PrintQueue.connector = fake
    #   ...
    #   fake.commands         # => [[:start, #<Printer::Job id: 7>], [:cancel, #<Printer::Job id: 7>]]
    #   fake.received(:start) # => [#<Printer::Job id: 7>]
    #
    #   PrintQueue::Connector::Fake.new(refusal: 'Prusa MK4 is no longer printing') # refuses pause, resume and cancel
    #
    # Out: what the printers and their spools would do, fired by hand. Each writes the printer's Printer::Status
    # snapshot the monitor would write, and saves the queue's event (`save!`: a refused event raises):
    #
    #   fake.ready!(printer)         # Operational, then PrintQueue::PrinterReady (asks for a dispatch pass)
    #   fake.offline!(printer)       # Offline, then PrintQueue::PrinterOffline
    #   fake.started!(copy)          # PrintQueue::PrintStart (the copy turns active), then Printing
    #   fake.progressed!(copy, 40)   # PrintQueue::PrintProgress, then Printing at 40%
    #   fake.paused!(copy)           # Paused, then PrintQueue::PrintPause
    #   fake.ended!(copy)            # Operational, then PrintQueue::PrintEnd ('completed', 'error' or 'cancelled')
    #
    # The dispatch requests still go to the spooler (PrintQueue::DispatchRequest): with no spooler running, run the pass
    # yourself (PrintQueue::Dispatch.new.save!). PrintQueue.connector= only swaps the connector of the process it runs
    # in: a spooler running elsewhere starts its copies on the real printers.
    #
    # In app/models rather than spec/support so the console can load it too.
    class Fake < Connector
      # The message pause, resume and cancel are refused with, nil to accept them
      attribute :refusal, :string

      #: (*untyped, **untyped) -> void
      def initialize(*, **)
        super
        @commands = [] #: Array[[Symbol, Printer::Job]]
      end

      # The commands received, in order: [name, copy], name one of :start, :pause, :resume, :cancel
      #: Array[[Symbol, Printer::Job]]
      attr_reader :commands

      # The copies the command was received for, in order
      #: (Symbol name) -> Array[Printer::Job]
      def received(name) = commands.filter_map { |command, printer_job| printer_job if command == name }

      # @override
      #: (Printer::Job printer_job) -> void
      def start(printer_job)
        commands << [:start, printer_job]
      end

      # @override
      #: (Printer::Job printer_job) -> Printer::Command
      def pause(printer_job) = answer(:pause, printer_job, Printer::Pause)

      # @override
      #: (Printer::Job printer_job) -> Printer::Command
      def resume(printer_job) = answer(:resume, printer_job, Printer::Resumption)

      # @override
      #: (Printer::Job printer_job) -> Printer::Command
      def cancel(printer_job) = answer(:cancel, printer_job, Printer::Cancellation)

      # The printer is connected and idle: its monitor writes Operational and records PrinterReady
      #: (Printer printer) -> void
      def ready!(printer)
        write_status(printer, Printer::StateFamily::Operational)
        PrintQueue::PrinterReady.new(printer:).save!
      end

      # The printer went offline: its monitor writes Offline and records PrinterOffline
      #: (Printer printer) -> void
      def offline!(printer)
        write_status(printer, Printer::StateFamily::Offline)
        PrintQueue::PrinterOffline.new(printer:).save!
      end

      # The copy's spool starts it: PrintStart (it must be enqueued), then the printer prints it
      #: (Printer::Job printer_job) -> void
      def started!(printer_job)
        PrintQueue::PrintStart.new(printer_job:).save!
        write_copy_status(printer_job, Printer::StateFamily::Printing, 0)
      end

      # The copy's print progressed (percent, 0 to 100)
      #: (Printer::Job printer_job, Numeric progress) -> void
      def progressed!(printer_job, progress)
        PrintQueue::PrintProgress.new(printer_job:, progress:).save!
        write_copy_status(printer_job, Printer::StateFamily::Printing, progress)
      end

      # The copy's print paused on the printer
      #: (Printer::Job printer_job) -> void
      def paused!(printer_job)
        write_copy_status(printer_job, Printer::StateFamily::Paused, printer_job.progress)
        PrintQueue::PrintPause.new(printer_job:).save!
      end

      # The copy's print is over: the printer is idle again (its monitor sees it first), then its spool records
      # PrintEnd, the print ended handler (it must be active: started! first), which asks for a dispatch pass.
      # result: 'completed', 'error' or 'cancelled'
      #: (Printer::Job printer_job, ?String result) -> void
      def ended!(printer_job, result = 'completed')
        write_status(T.must(printer_job.printer), Printer::StateFamily::Operational)
        PrintQueue::PrintEnd.new(printer_job:, result:).save!
      end

      private

      # Records the command, and answers it: accepted (no errors), or refused with `refusal` in errors[:base]. The
      # command isn't saved: it would call the printer.
      #: (Symbol name, Printer::Job printer_job, singleton(Printer::Command) command_class) -> Printer::Command
      def answer(name, printer_job, command_class)
        commands << [name, printer_job]
        command = command_class.new(printer: printer_job.printer)
        command.errors.add(:base, refusal) if refusal
        command
      end

      # The snapshot of the copy's printer, printing it
      #: (Printer::Job printer_job, Printer::StateFamily family, Numeric? progress) -> void
      def write_copy_status(printer_job, family, progress)
        write_status(T.must(printer_job.printer), family, printer_job:, progress:)
      end

      # Writes the snapshot the monitor would (Printer::Status#save!, which pushes printerStatusChanged). The camera
      # and temperatures of a snapshot already written are kept.
      #: (Printer printer, Printer::StateFamily family, ?printer_job: Printer::Job?, ?progress: Numeric?) -> void
      def write_status(printer, family, printer_job: nil, progress: nil)
        status = Printer::Status.find_or_initialize_by(printer:)
        now = Time.current
        status.assign_attributes(
          state_family: family, state_text: family.serialize.capitalize, error_text: nil,
          file_name: printer_job&.name, progress:, print_time_left: nil, updated_at: now,
          last_seen_at: family == Printer::StateFamily::Offline ? status.last_seen_at : now
        )
        status.save!
      end
    end
  end
end
