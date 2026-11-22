# frozen_string_literal: true

module Library
  # A label on a file (the file_labels join table)
  #
  #   item.labels << label # creates the Library::Labeling
  class Labeling < ApplicationRecord
    self.table_name = 'file_labels'

    # file_record_id keeps its name from before the Library namespace
    belongs_to :item, class_name: 'Library::Item', foreign_key: :file_record_id, inverse_of: :labelings
    belongs_to :label, class_name: 'Library::Label', inverse_of: :labelings

    validates :file_record_id, uniqueness: { scope: :label_id }
  end
end
