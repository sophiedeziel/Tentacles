# typed: true
# frozen_string_literal: true

module PrintQueue
  # The printers an entry is limited to, as PrintQueue::Addition and PrintQueue::JobUpdate are given them: every
  # printer that can print it (`all_capable`, printers added later included), or a list of printer ids. Says why a list
  # is refused: empty, a printer that no longer exists, or a printer that can never print the entry (a hard limitation,
  # PrintQueue::HardLimitations, read from `needs`: the needs of the entry as it will be saved).
  #
  #   choice = PrintQueue::PrinterChoice.new(needs:, all_capable: false, printer_ids: [mini.id])
  #   choice.refusal  # => "Mini Delta can't print it: Bed too small: needs 120 × 80 mm, has a 110 mm round bed"
  #   choice.printers # => [mini]: empty when all_capable
  #
  # Offline printers and printers without the filament loaded are never refused: they take it once that changes.
  class PrinterChoice < ApplicationModel
    # The PrintQueue::Needs of the entry
    attribute :needs
    attribute :all_capable, :boolean, default: true
    # Printer ids (Integers or Strings), when all_capable is off. Ignored otherwise
    attribute :printer_ids, default: -> { [] }

    # The printers listed, by id: empty when all_capable
    #: -> Array[Printer]
    def printers
      return [] if all_capable

      @printers ||= Printer.where(id: ids).order(:id).to_a
    end

    # Why the list is refused, nil when it isn't (always nil when all_capable)
    #: -> String?
    def refusal
      return if all_capable
      return 'Choose at least one printer' if ids.empty?
      return 'One of the printers chosen no longer exists' if printers.size < ids.size

      hard_limit
    end

    # @override
    #: -> bool
    def readonly? = true

    private

    # The first printer listed that can never print it, with why
    #: -> String?
    def hard_limit
      printers.each do |printer|
        reasons = PrintQueue::HardLimitations.new(needs:, printer:).reasons
        return "#{printer.name} can't print it: #{reasons.map(&:message).join('. ')}" if reasons.any?
      end
      nil
    end

    #: -> Array[String]
    def ids = Array(printer_ids).compact_blank.map(&:to_s).uniq
  end
end
