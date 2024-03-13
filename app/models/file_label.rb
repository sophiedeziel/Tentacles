# frozen_string_literal: true

class FileLabel < ApplicationRecord
  belongs_to :file_record
  belongs_to :label

  validates :file_record_id, uniqueness: { scope: :label_id }
end
