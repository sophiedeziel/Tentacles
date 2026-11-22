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
        labels = ::Library::Label.where(id: label_ids)
        files = ::Library::Item.where(id: file_ids).includes(:labelings)

        return { labels: [], files: [] } if labels.empty? || files.empty?

        files.each do |file|
          file.labelings.each { |labeling| labeling.destroy! if labels.map(&:id).include?(labeling.label_id) }
        end

        { labels:, files: }
      rescue StandardError
        { labels: [], files: [] }
      end
    end
  end
end
