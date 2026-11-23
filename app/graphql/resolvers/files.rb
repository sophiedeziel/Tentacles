# typed: true
# frozen_string_literal: true

module Resolvers
  # The files of the library, or only its G-code files: the ones the global queue can print (the Add to Queue file
  # picker)
  class Files < GraphQL::Schema::Resolver
    argument_class Base::Argument

    description 'files'

    type [Types::File], null: false

    argument :gcode, Boolean, required: false, default_value: false, replace_null_with_default: true,
                              description: 'Only the G-code files (.gcode): the ones the global queue can print'

    #: (gcode: bool) -> ActiveRecord::Relation
    def resolve(gcode:)
      items = ::Library::Item.includes(:labels).with_attached_file
      gcode ? items.gcode : items
    end
  end
end
