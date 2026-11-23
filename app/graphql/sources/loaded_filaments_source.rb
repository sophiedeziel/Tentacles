# typed: true
# frozen_string_literal: true

module Sources
  # Batches the loaded filaments of the printers of a query (the fleet list, the dashboard, a printerStatusChanged
  # push) into a single SQL query.
  #
  #   dataloader.with(Sources::LoadedFilamentsSource).load(printer.id) # => [Printer::LoadedFilament], by slot
  class LoadedFilamentsSource < GraphQL::Dataloader::Source
    extend T::Sig

    sig { params(printer_ids: T::Array[Integer]).returns(T::Array[T::Array[::Printer::LoadedFilament]]) }
    def fetch(printer_ids)
      filaments = ::Printer::LoadedFilament.where(printer_id: printer_ids).order(:slot).group_by(&:printer_id)
      printer_ids.map { |printer_id| filaments.fetch(printer_id, []) }
    end
  end
end
