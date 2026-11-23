# typed: true
# frozen_string_literal: true

module PrintQueue
  # Adds a file to the global queue, at the bottom. See PrintQueue::Operation.
  #
  #   addition = PrintQueue::Addition.new(item:, copies: 3, colour: 'Black')
  #   addition.save # => true
  #   addition.job  # => the new PrintQueue::Job
  #
  #   PrintQueue::Addition.new(item:, all_capable: false, printer_ids: [mk4.id]) # only on the MK4
  #
  # Asks for a dispatch pass: an idle printer may fit it.
  class Addition < Operation
    # The Library::Item to print
    attribute :item
    attribute :copies, :integer, default: 1
    # The colour asked for, nil for Any colour
    attribute :colour, :string
    # Every copy on the same printer: bound to the printer of its first copy
    attribute :same_printer, :boolean, default: false
    # "All that can print it", printers added later included. When off, only on `printer_ids`
    attribute :all_capable, :boolean, default: true
    # Printer ids (Integers or Strings), when all_capable is off. Ignored otherwise
    attribute :printer_ids, default: -> { [] }

    validates :item, presence: true
    validate :item_in_library
    validates :copies, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :colour, length: { maximum: 40 }
    validate :printers_chosen, unless: :all_capable

    # The entry added, once saved
    #: PrintQueue::Job?
    attr_reader :job

    private

    # @override
    #: -> void
    def change
      @job = PrintQueue::Job.create!(item:, copies:, colour:, same_printer:, all_capable:, position: next_position,
                                     printers: all_capable ? [] : chosen_printers)
    end

    #: -> bool
    def dispatches? = true

    #: -> Array[Printer]
    def chosen_printers = Printer.where(id: chosen_ids).to_a

    #: -> Array[String]
    def chosen_ids = Array(printer_ids).compact_blank.map(&:to_s).uniq

    #: -> void
    def item_in_library
      errors.add(:item, 'must be a file of the library') if item && !item.is_a?(Library::Item)
    end

    #: -> void
    def printers_chosen
      ids = chosen_ids
      if ids.empty?
        errors.add(:base, 'Choose at least one printer')
      elsif Printer.where(id: ids).count < ids.size
        errors.add(:base, 'One of the printers chosen no longer exists')
      end
    end
  end
end
