# frozen_string_literal: true

module Sources
  # Batches the PrinterStatus lookups of a query into a single Redis MGET.
  #
  #   dataloader.with(Sources::PrinterStatusSource).load(printer.id) # => PrinterStatus or nil
  #
  # When Redis can't be reached, every printer resolves to nil (shown as unknown) rather than failing the query.
  class PrinterStatusSource < GraphQL::Dataloader::Source
    def fetch(printer_ids)
      statuses = PrinterStatusStore.read_many(printer_ids)
      printer_ids.map { |printer_id| statuses[printer_id] }
    rescue Redis::BaseError => e
      Rails.logger.warn("[PrinterStatusSource] Could not read the printer statuses: #{e.message}")
      Array.new(printer_ids.size)
    end
  end
end
