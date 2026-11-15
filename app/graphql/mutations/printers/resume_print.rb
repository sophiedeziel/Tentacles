# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    class ResumePrint < PrinterAction
      description 'Resumes the paused print of a printer (allowed while PAUSED)'

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
