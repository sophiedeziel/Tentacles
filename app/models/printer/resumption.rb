# typed: true
# frozen_string_literal: true

class Printer
  # Resumes the paused print (allowed while PAUSED). See Printer::Command.
  #
  #   resumption = Printer::Resumption.new(printer:, expected_file_name: 'cube.gcode')
  #   resumption.save          # => false when refused or when the printer fails
  #   resumption.errors[:base] # => ['Prusa MK4 is no longer paused']
  class Resumption < Command
    private

    def refusal(family)
      "#{printer.name} is no longer paused" unless family == StateFamily::Paused
    end

    # To the job that was checked, not to one that started since
    def persist
      printer.api.resume(job_id: live_job.job_id)
    end
  end
end
