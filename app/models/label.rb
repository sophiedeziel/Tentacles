# frozen_string_literal: true

class Label < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :color, presence: true,
                    format: { with: /\A#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\Z/ }

  has_many :file_labels, dependent: :destroy
  has_many :file_records, through: :file_labels
end
