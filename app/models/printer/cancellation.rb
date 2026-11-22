# typed: true
# frozen_string_literal: true

class Printer
  # Cancels the print under way (allowed while PRINTING or PAUSED). See Printer::Command.
  #
  #   cancellation = Printer::Cancellation.new(printer:, expected_file_name: 'cube.gcode')
  #   cancellation.save          # => false when refused or when the printer fails
  #   cancellation.errors[:base] # => ['Prusa MK4 is now printing gear.gcode']
  class Cancellation < Command
    CANCELLABLE = T.let([StateFamily::Printing, StateFamily::Paused].freeze, T::Array[StateFamily])

    private

    def refusal(family)
      "#{printer.name} is no longer printing" unless CANCELLABLE.include?(family)
    end

    # To the job that was checked, not to one that started since
    def persist
      printer.api.cancel(job_id: live_job.job_id)
    end
  end
end
