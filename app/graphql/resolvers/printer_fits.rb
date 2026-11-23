# typed: true
# frozen_string_literal: true

module Resolvers
  # The Printers of the Add to Queue form: how every printer fits the file with the filament asked for, from a
  # ::PrintQueue::Estimate (the rule the dispatcher uses, PrintQueue::Fit), with the query's fleet.
  class PrinterFits < GraphQL::Schema::Resolver
    argument_class Base::Argument

    description 'How every printer fits the file with this filament, by printer id: the Printers of the Add to Queue ' \
                'form. Null while the global queue is off, or for an unknown file.'

    type [Types::PrinterFit], null: true

    argument :file_id, ID, required: true
    argument :material, String, required: false, description: 'The material asked for. Null for the one its G-code says'
    argument :colour, String, required: false, description: 'The colour asked for. Null for Any colour'

    #: (file_id: String, ?material: String?, ?colour: String?) -> Array[::PrintQueue::Fit]?
    def resolve(file_id:, material: nil, colour: nil)
      return unless ::PrintQueue.enabled?

      item = ::Library::Item.find_by(id: file_id)
      return if item.nil?

      ::PrintQueue::Estimate.new(item:, material:, colour:, fleet: dataloader.with(Sources::FleetSource).load(:current))
                            .fits
    end
  end
end
