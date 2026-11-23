# typed: true
# frozen_string_literal: true

module Sources
  # The printers that can print each print job of a query (PrintQueue::Fleet#capable), from the query's fleet and
  # their needs: one query for their printer lists.
  #
  #   dataloader.with(Sources::EligiblePrintersSource).load(print_job) # => [Printer], by id
  class EligiblePrintersSource < GraphQL::Dataloader::Source
    #: (Array[::PrintQueue::Job] print_jobs) -> Array[Array[::Printer]]
    def fetch(print_jobs)
      fleet = dataloader.with(FleetSource).load(:current)
      needs = dataloader.with(PrintJobNeedsSource).load_all(print_jobs)
      ActiveRecord::Associations::Preloader.new(records: print_jobs, associations: :job_printers).call
      print_jobs.zip(needs).map { |print_job, print_job_needs| fleet.capable(print_job, needs: print_job_needs) }
    end
  end
end
