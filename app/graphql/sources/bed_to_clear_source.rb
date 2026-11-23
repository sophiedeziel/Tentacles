# typed: true
# frozen_string_literal: true

module Sources
  # The print still on the bed of each printer of a query, in one query (Printer.beds_to_clear).
  #
  #   dataloader.with(Sources::BedToClearSource).load(printer.id) # => Printer::Job, or nil when its bed is clear
  class BedToClearSource < GraphQL::Dataloader::Source
    #: (Array[Integer] printer_ids) -> Array[::Printer::Job?]
    def fetch(printer_ids)
      prints = ::Printer.beds_to_clear(printer_ids)
      printer_ids.map { |id| prints[id] }
    end
  end
end
