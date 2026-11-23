# typed: true
# frozen_string_literal: true

module Sources
  # The global queue as each printer of a query sees it (PrintQueue::Lineup: Up Next and Skipped), from the query's
  # fleet and candidates: no query of its own.
  #
  #   dataloader.with(Sources::LineupSource).load(printer) # => PrintQueue::Lineup
  class LineupSource < GraphQL::Dataloader::Source
    #: (Array[::Printer] printers) -> Array[::PrintQueue::Lineup]
    def fetch(printers)
      fleet = dataloader.with(FleetSource).load(:current)
      entries = dataloader.with(CandidatesSource).load(:current)
      printers.map do |printer|
        # The fleet's copy has its loaded filaments loaded
        loaded = fleet.printer(printer.id) || printer
        ::PrintQueue::Lineup.new(printer: loaded, status: fleet.status(loaded), entries:, printers: fleet.printers)
      end
    end
  end
end
