# frozen_string_literal: true

module Mutations
  class SendFilesToPrinters < Mutations::BaseMutation
    description 'Mutation to upload a file to printers'

    argument :file_ids, [ID], required: true
    argument :printer_ids, [ID], required: true

    field :job_enqueued, Boolean, null: true

    def resolve(file_ids:, printer_ids:)
      file_ids = file_ids.map(&:presence).compact
      printer_ids = printer_ids.map(&:presence).compact
      return { job_enqueued: false } if file_ids.empty? || printer_ids.empty?

      UploadFilesToPrintersJob.perform_later(file_ids, printer_ids)
      { job_enqueued: true }
    end
  end
end
