# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :uploadFile, mutation: Mutations::UploadFile
  end
end
