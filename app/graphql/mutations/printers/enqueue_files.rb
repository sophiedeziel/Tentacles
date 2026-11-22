# frozen_string_literal: true

module Mutations
  module Printers
    class EnqueueFiles < Base::Mutation
      description 'Mutation to upload a file to printers'

      argument :file_ids, [ID], required: true
      argument :printer_ids, [ID], required: true

      field :jobs, [Types::Job], null: true

      def resolve(file_ids:, printer_ids:)
        jobs = []
        file_ids.each do |file_id|
          file = ::Library::Item.find(file_id)
          printer_ids.each { |printer_id| jobs << create_job(file, printer_id) }
        end
        { jobs: }
      ensure
        # Once per printer, for the jobs enqueued, even when a later file or printer wasn't found
        jobs.select(&:persisted?).uniq(&:printer_id).each(&:push_print_queue_changed)
      end

      private

      def create_job(file, printer_id)
        printer = ::Printer.find(printer_id)
        print_immediately = printer.queue.size == 1

        job = ::Printer::Job.create(
          name: "Job for file #{file.id}",
          status: 'enqueued',
          executable: file,
          printer:
        )
        printer.notify_spooler(::Printer::SpoolerCommand::StartPrint) if print_immediately
        job
      end
    end
  end
end
