# typed: true
# frozen_string_literal: true

module PrintQueue
  # Changes the options of an entry still in the queue, as the Edit page saves them: its copies, the material and
  # colour it asks for, whether every copy prints on the same printer, and its printers. Every option is set: those
  # not given take their default (the G-code's material, Any colour, any printer, every printer that can print it).
  # Its place in the queue and its hold keep their own operations (PrintQueue::Move, PrintQueue::Hold). See
  # PrintQueue::Operation.
  #
  #   update = PrintQueue::JobUpdate.new(job:, copies: 4, material: 'PETG', colour: nil, same_printer: false,
  #                                      all_capable: false, printer_ids: [voron.id])
  #   update.save          # => false
  #   update.errors[:base] # => ["Can't go below 3: 2 done and 1 printing"]
  #
  # The change applies to the copies still waiting: copies printing or done keep what they were started with. Refused
  # below the copies done and printing (PrintQueue::CopiesChange.below_floor), for an entry no longer in the queue, and
  # for a printer list naming a printer that can never print it (PrintQueue::PrinterChoice).
  #
  # The printer a same-printer batch is bound to is PrintQueue::BatchPrinter's: unbound when same_printer goes off or
  # its printer is no longer allowed, bound to the printer it already prints on when same_printer goes on. Asks for a
  # dispatch pass: the change may make a printer eligible.
  class JobUpdate < EntryOperation
    attribute :copies, :integer
    # The material asked for (a key of Filament::MATERIALS), nil for the one its G-code says
    attribute :material, :string
    # The colour asked for, nil for Any colour
    attribute :colour, :string
    attribute :same_printer, :boolean, default: false
    # "All that can print it", printers added later included. When off, only on `printer_ids`
    attribute :all_capable, :boolean, default: true
    # Printer ids (Integers or Strings), when all_capable is off. Ignored otherwise
    attribute :printer_ids, default: -> { [] }

    validates :copies, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :material, inclusion: { in: Filament::MATERIALS }, allow_nil: true
    validates :colour, length: { maximum: 40 }
    validate :printers_chosen, unless: :refused?
    validate :allowed, unless: :refused?

    # A key of Filament::MATERIALS ("pla" is "PLA"), nil when blank
    #: (untyped value) -> void
    def material=(value)
      super(Filament.material_key(value).presence)
    end

    private

    #: -> String?
    def refusal = no_longer_queued || PrintQueue::CopiesChange.below_floor(job, copies.to_i)

    # @override
    #: -> void
    def change
      @previous = job.bound_printer
      job.bound_printer = batch_printer
      job.assign_attributes(copies:, material:, colour:, same_printer:, all_capable:, printers: printer_choice.printers)
      job.save!
    end

    #: -> Printer?
    def batch_printer = PrintQueue::BatchPrinter.new(job:, same_printer:, all_capable:, printer_ids:).printer

    # The printer it was bound to, even once released
    #: -> Array[Printer]
    def pushed_printers = [@previous, job.bound_printer].compact.uniq

    #: -> bool
    def dispatches? = true

    #: -> PrintQueue::PrinterChoice
    def printer_choice
      @printer_choice ||= PrintQueue::PrinterChoice.new(
        needs: PrintQueue::Job.new(item: job.item, material:, colour:).needs, all_capable:, printer_ids:
      )
    end

    #: -> void
    def printers_chosen
      message = printer_choice.refusal
      errors.add(:base, message) if message
    end
  end
end
