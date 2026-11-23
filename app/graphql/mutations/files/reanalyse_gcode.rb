# typed: true
# frozen_string_literal: true

module Mutations
  module Files
    # The Re-analyse button of a G-code summary that failed
    class ReanalyseGcode < Base::Mutation
      description "Reads a G-code file's summary again, in the background: the returned file's gcodeSummary is " \
                  'PENDING until it is read'

      argument :file_id, ID, required: true

      field :file, Types::File, null: true, description: 'The file, null when it was not found'
      field :errors, [Types::UserError], null: false, description: 'Why it was not read again, empty when it was'

      #: (file_id: String) -> Hash[Symbol, untyped]
      def resolve(file_id:)
        item = ::Library::Item.find_by(id: file_id)
        return { file: nil, errors: [Types::UserError.base('File not found')] } if item.nil?

        scheduling = ::Library::GcodeSummaryScheduling.new(item:)
        { file: item, errors: scheduling.save ? [] : Types::UserError.from(scheduling.errors) }
      end
    end
  end
end
