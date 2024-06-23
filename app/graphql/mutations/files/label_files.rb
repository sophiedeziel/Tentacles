# frozen_string_literal: true

module Mutations
  module Files
    class LabelFiles < Base::Mutation
      description 'Attaches labels to files'

      argument :file_ids, [ID], required: true
      argument :label_ids, [ID], required: true

      field :labels, [Types::Label], null: true
      field :files, [Types::File], null: true

      def resolve(file_ids:, label_ids:)
        labels = ::Label.where(id: label_ids)
        files = ::FileRecord.where(id: file_ids)

        return { labels: [], files: [] } if labels.empty? || files.empty?

        files.each do |file|
          to_save = labels.reject { |label| file.labels.include?(label) }
          file.labels << to_save if to_save.any?
          file.save!
        end

        { labels:, files: }
      rescue StandardError
        { labels: [], files: [] }
      end
    end
  end
end
