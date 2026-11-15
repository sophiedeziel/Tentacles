# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    class PausePrint < PrinterAction
      description 'Pauses the print under way on a printer (allowed while PRINTING)'

      argument :expected_file_name, String, required: false,
                                            description: 'The file the user confirmed for: refuses when the ' \
                                                         'printer is printing another one'

      private

      def refusal(printer, family)
        "#{printer.name} is no longer printing" unless family == PrinterStateFamily::Printing
      end

      def send_command(printer)
        printer.api.pause(job_id: live_job_id)
      end
    end
  end
end
