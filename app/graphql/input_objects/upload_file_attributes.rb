# frozen_string_literal: true

module InputObjects
  class UploadFileAttributes < Base::InputObject
    description 'Attributes for uploading a file'
    argument :notes, String, required: false
    argument :file, ::Types::UploadFile, required: true
  end
end
