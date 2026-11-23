# typed: true
# frozen_string_literal: true

class Printer
  # The printer's state family and the job under way, read fresh from the printer's server (not the monitor's
  # snapshot), for the printer commands (see Printer::Command):
  #
  #   live_job = Printer::LiveJob.find_by(printer:)
  #   live_job.state_family # => Printer::StateFamily::Printing
  #   live_job.file_name    # => 'cube.gcode', the name the monitor reports (Printer::Status#file_name)
  #   live_job.job_id       # => 7, to pass to `printer.api.pause(job_id:)`. nil for the backends without job ids
  #                         #    (OctoPrint)
  #
  # `file_name` and `job_id` are nil when no job is loaded. Read-only: the printer's state changes through the
  # commands (Printer::Pause, Printer::Cancellation, ...), so #save raises ReadOnlyRecord.
  class LiveJob < ApplicationModel
    attribute :printer
    attribute :state_family, EnumType.new(Printer::StateFamily)
    attribute :file_name, :string
    attribute :job_id, :integer

    class << self
      # Reads it from the printer in a single round trip (two for PrusaLink during a job), through the adapter's
      # #live_job. Never nil: raises the adapter's errors (Printer::Backend::Error, ...) when it can't be read.
      #: (printer: Printer) -> LiveJob
      def find_by(printer:)
        new(printer:, **printer.api.live_job)
      end
    end

    #: -> bool
    def readonly?
      true
    end
  end
end
