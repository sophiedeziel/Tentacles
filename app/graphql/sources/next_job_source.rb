# typed: true
# frozen_string_literal: true

module Sources
  # The next job of each printer's queue, with its file preloaded: the jobs come from PrinterJobsSource (shared
  # with canStartNext and queuedCount), then their files load in one query per association, whatever the number of
  # printers.
  #
  #   dataloader.with(Sources::NextJobSource).load(printer.id) # => Printer::Job or nil
  class NextJobSource < GraphQL::Dataloader::Source
    #: (Array[Integer] printer_ids) -> Array[::Printer::Job?]
    def fetch(printer_ids)
      jobs = dataloader.with(PrinterJobsSource).load_all(printer_ids).map(&:next_job)
      ActiveRecord::Associations::Preloader.new(records: jobs.compact,
                                                associations: { executable: { file_attachment: :blob } }).call
      jobs
    end
  end
end
