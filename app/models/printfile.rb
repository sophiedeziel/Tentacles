class Printfile < ApplicationRecord
  def filetype
    '.' + filename.split('.').last
  end
end
