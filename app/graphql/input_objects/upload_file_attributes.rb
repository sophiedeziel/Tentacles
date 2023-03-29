# frozen_string_literal: true

module InputObjects
  class UploadFileAttributes < Types::BaseInputObject
    description 'Attributes for uploading a file'
    argument :notes, String, required: false
    argument :file, ::Types::UploadFile, required: true
  end
end
