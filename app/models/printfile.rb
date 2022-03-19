# frozen_string_literal: true

class Printfile < ApplicationRecord
  has_one_attached :file

  def filename
    file.filename.to_s
  end

  def filetype
    ".#{filename.split('.').last}"
  end
end
