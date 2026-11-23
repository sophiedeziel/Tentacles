# typed: true
# frozen_string_literal: true

module PrintQueue
  # Adds a file to the global queue, at the bottom or at the top: the Add to Queue form. See PrintQueue::Operation.
  #
  #   addition = PrintQueue::Addition.new(item:, copies: 3, material: 'PLA', colour: 'Black')
  #   addition.save # => true
  #   addition.job  # => the new PrintQueue::Job
  #
  #   PrintQueue::Addition.new(item:, all_capable: false, printer_ids: [mk4.id]) # only on the MK4
  #   PrintQueue::Addition.new(item:, position: 'top', held: true)              # Next Up, held until released
  #
  # A printer list is refused when it names a printer that can never print it (PrintQueue::PrinterChoice). At the top,
  # the entries still in the queue are numbered 1..n again (as PrintQueue::Move does). Asks for a dispatch pass: an
  # idle printer may fit it.
  class Addition < Operation
    PLACES = %w[top bottom].freeze #: Array[String]

    # The Library::Item to print
    attribute :item
    attribute :copies, :integer, default: 1
    # The material asked for (a key of Filament::MATERIALS), nil for the one its G-code says
    attribute :material, :string
    # The colour asked for, nil for Any colour
    attribute :colour, :string
    # Every copy on the same printer: bound to the printer of its first copy
    attribute :same_printer, :boolean, default: false
    # "All that can print it", printers added later included. When off, only on `printer_ids`
    attribute :all_capable, :boolean, default: true
    # Printer ids (Integers or Strings), when all_capable is off. Ignored otherwise
    attribute :printer_ids, default: -> { [] }
    # 'bottom' (End of Queue) or 'top' (Next Up: ahead of everything waiting)
    attribute :position, :string, default: 'bottom'
    # Held: it keeps its place, but no copy starts until it's released
    attribute :held, :boolean, default: false

    validates :item, presence: true
    validate :item_in_library
    validates :copies, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :material, inclusion: { in: Filament::MATERIALS }, allow_nil: true
    validates :colour, length: { maximum: 40 }
    validates :position, inclusion: { in: PLACES }
    validate :printers_chosen, unless: :refused?

    # The entry added, once saved
    #: PrintQueue::Job?
    attr_reader :job

    # A key of Filament::MATERIALS ("pla" is "PLA"), nil when blank
    #: (untyped value) -> void
    def material=(value)
      super(Filament.material_key(value).presence)
    end

    private

    # @override
    #: -> void
    def change
      @job = PrintQueue::Job.create!(item:, copies:, material:, colour:, same_printer:, all_capable:, held:,
                                     position: next_position, printers: printer_choice.printers)
      move_to_top if position == 'top'
    end

    #: -> bool
    def dispatches? = true

    # First among the entries still in the queue, which are numbered 1..n again
    #: -> void
    def move_to_top
      entry = job #: as !nil
      renumber([entry, *PrintQueue::Job.unfinished.in_queue_order.where.not(id: entry.id)])
    end

    #: -> PrintQueue::PrinterChoice
    def printer_choice
      @printer_choice ||= PrintQueue::PrinterChoice.new(
        needs: PrintQueue::Job.new(item:, material:, colour:).needs, all_capable:, printer_ids:
      )
    end

    #: -> void
    def item_in_library
      errors.add(:item, 'must be a file of the library') if item && !item.is_a?(Library::Item)
    end

    #: -> void
    def printers_chosen
      message = printer_choice.refusal
      errors.add(:base, message) if message
    end
  end
end
