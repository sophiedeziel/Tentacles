# typed: true
# frozen_string_literal: true

module Sources
  # The PrintQueue::Forecast, run once per query (whatever key), for the whole queue, with the query's
  # PrintQueue::Fleet and candidates: What Happens Next of every print job and what every printer takes next read the
  # same one.
  #
  #   dataloader.with(Sources::ForecastSource).load(:current).outcome(print_job) # => Forecast::Outcome, or nil
  #   dataloader.with(Sources::ForecastSource).load(:current).takes_next(printer) # => PrintQueue::Job, or nil
  class ForecastSource < GraphQL::Dataloader::Source
    #: (Array[Symbol] keys) -> Array[::PrintQueue::Forecast]
    def fetch(keys)
      fleet = dataloader.with(FleetSource).load(:current)
      entries = dataloader.with(CandidatesSource).load(:current)
      forecast = ::PrintQueue::Forecast.current(fleet:, entries:)
      keys.map { forecast }
    end
  end
end
