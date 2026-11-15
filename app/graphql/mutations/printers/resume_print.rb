# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    class ResumePrint < PrinterAction
      description 'Resumes the paused print of a printer (allowed while PAUSED)'

      argument :expected_file_name, String, required: false,
                                            description: 'The file the user confirmed for: refuses when the ' \
                                                         'printer is printing another one'

      private

      def refusal(printer, family)
        "#{printer.name} is no longer paused" unless family == PrinterStateFamily::Paused
      end

      def send_command(_printer)
        Octoprint::Job.resume
      end
    end
  end
end
