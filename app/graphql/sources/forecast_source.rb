# typed: true
# frozen_string_literal: true

module Sources
  # What Happens Next for the print jobs of a query: PrintQueue::Forecast runs once, for the whole queue, with the
  # query's PrintQueue::Fleet.
  #
  #   dataloader.with(Sources::ForecastSource).load(print_job.id) # => PrintQueue::Forecast::Outcome, or nil
  class ForecastSource < GraphQL::Dataloader::Source
    #: (Array[Integer] print_job_ids) -> Array[::PrintQueue::Forecast::Outcome?]
    def fetch(print_job_ids)
      fleet = dataloader.with(FleetSource).load(:current)
      outcomes = ::PrintQueue::Forecast.current(fleet:).outcomes
      print_job_ids.map { |id| outcomes[id] }
    end
  end
end
