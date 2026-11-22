# typed: true
# frozen_string_literal: true

module Mutations
  module Printers
    # Saves a Printer::Resumption
    class ResumePrint < PrinterAction
      description 'Resumes the paused print of a printer (allowed while PAUSED)'

      argument :expected_file_name, String, required: false,
                                            description: 'The file the user confirmed for: refuses when the ' \
                                                         'printer is printing another one'

      private

      def command_class = ::Printer::Resumption
    end
  end
end
