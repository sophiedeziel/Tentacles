# typed: true
# frozen_string_literal: true

class Printer
  # Pauses the print under way (allowed while PRINTING). See Printer::Command.
  #
  #   pause = Printer::Pause.new(printer:, expected_file_name: 'cube.gcode')
  #   pause.save          # => false when refused or when the printer fails
  #   pause.errors[:base] # => ['Prusa MK4 is no longer printing']
  class Pause < Command
    private

    def refusal(family)
      "#{printer.name} is no longer printing" unless family == StateFamily::Printing
    end

    # To the job that was checked, not to one that started since
    def send_command
      printer.api.pause(job_id: live_job.job_id)
    end
  end
end
