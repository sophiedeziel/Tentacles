# typed: true
# frozen_string_literal: true

module Resolvers
  # The Summary of the Add to Queue form (and of the Edit page): a ::PrintQueue::Estimate of the options addToQueue
  # takes, with the query's fleet and candidates. Read-only.
  class QueueEstimate < GraphQL::Schema::Resolver
    argument_class Base::Argument

    description 'The summary of the Add to Queue form, or of the Edit page with printJobId, from the same options as ' \
                'addToQueue. Null while the global queue is off, or for an unknown file or print job.'

    type Types::QueueEstimate, null: true

    argument :file_id, ID, required: true, description: "Ignored with printJobId: the print job's own file"
    argument :copies, Integer, required: false, default_value: 1, replace_null_with_default: true
    argument :material, String, required: false, description: 'The material asked for. Null for the one its G-code says'
    argument :colour, String, required: false, description: 'The colour asked for. Null for Any colour'
    argument :same_printer, Boolean, required: false, default_value: false, replace_null_with_default: true
    argument :printer_ids, [ID], required: false, description: 'Null for every printer that can print it'
    argument :position, Types::MovePrintJobTo, required: false, default_value: 'bottom',
                                               replace_null_with_default: true,
                                               description: 'Ignored with printJobId: it keeps its place'
    argument :held, Boolean, required: false, default_value: false, replace_null_with_default: true
    argument :print_job_id, ID, required: false,
                                description: 'The print job edited: the form replaces it in the queue, and only its ' \
                                             'copies still to start are counted'

    #: (file_id: String, ?print_job_id: String?, ?printer_ids: Array[String]?, **untyped)
    #|   -> ::PrintQueue::Estimate?
    def resolve(file_id:, print_job_id: nil, printer_ids: nil, **)
      return unless ::PrintQueue.enabled?

      job = ::PrintQueue::Job.find_by(id: print_job_id) if print_job_id
      item = item_of(job, file_id) unless print_job_id && job.nil?
      return if item.nil?

      ::PrintQueue::Estimate.new(item:, job:, all_capable: printer_ids.nil?, printer_ids: printer_ids || [],
                                 fleet: dataloader.with(Sources::FleetSource).load(:current),
                                 entries: dataloader.with(Sources::CandidatesSource).load(:current), **)
    end

    private

    # The print job's own file: a fileId of another file would estimate the wrong summary
    #: (::PrintQueue::Job? job, String file_id) -> ::Library::Item?
    def item_of(job, file_id) = job ? job.item : ::Library::Item.find_by(id: file_id)
  end
end
