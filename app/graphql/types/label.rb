# frozen_string_literal: true

module Types
  class Label < Base::Object
    field :id, ID, null: false
    field :name, String, null: false
    field :color, String, null: false
    field :files, File.connection_type, method: :file_records, null: false
  end
end
