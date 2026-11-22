# frozen_string_literal: true

module Library
  # A label that sorts the library's files (a file can have many)
  #
  #   label = Library::Label.create!(name: 'Calibration', color: '#ff8800')
  #   label.items # the files it labels, through Library::Labeling
  class Label < ApplicationRecord
    validates :name, presence: true, uniqueness: true
    validates :color, presence: true,
                      format: { with: /\A#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\Z/ }

    has_many :labelings, class_name: 'Library::Labeling', inverse_of: :label, dependent: :destroy
    has_many :items, through: :labelings
  end
end
