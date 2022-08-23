# frozen_string_literal: true

module Mutations
  class EnqueueFiles < Mutations::BaseMutation
    description 'Mutation to upload a file to printers'

    argument :file_ids, [ID], required: true
    argument :printer_ids, [ID], required: true

    field :jobs, [Types::JobType], null: true

    def resolve(file_ids:, printer_ids:)
      jobs = file_ids.flat_map do |file_id|
        file = FileManager::File.find(file_id)
        printer_ids.map do |printer_id|
          create_job(file, printer_id)
        end
      end
      { jobs: jobs }
    end

    private

    def create_job(file, printer_id)
      print_immediately = Printer::Job.queue(printer_id).size == 1

      job = Printer::Job.create(
        name: "Job for file #{file.id}",
        status: 'enqueued',
        executable: file,
        printer_id: printer_id
      )

      if print_immediately
        Redis.current.publish('printers',
                              { command: :start_print,
                                printer_id: printer_id }.to_json)
      end

      job
    end
  end
end
