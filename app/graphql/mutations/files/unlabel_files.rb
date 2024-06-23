# frozen_string_literal: true

module Mutations
  module Files
    class UnlabelFiles < Base::Mutation
      description 'Removes labels from files'

      argument :file_ids, [ID], required: true
      argument :label_ids, [ID], required: true

      field :labels, [Types::Label], null: true
      field :files, [Types::File], null: true

      def resolve(file_ids:, label_ids:)
        labels = ::Label.where(id: label_ids)
        files = ::FileRecord.where(id: file_ids).includes(:file_labels)

        return { labels: [], files: [] } if labels.empty? || files.empty?

        files.each do |file|
          file.file_labels.each { |file_label| file_label.destroy! if labels.map(&:id).include?(file_label.label_id) }
        end

        { labels:, files: }
      rescue StandardError
        { labels: [], files: [] }
      end
    end
  end
end
