class Mutations::UploadFile < Mutations::BaseMutation
  description "Mutation to upload a file"
  
  argument :file_attributes,
    InputObjects::UploadFileAttributes,
    required: true
  
  field :printfile, Types::PrintfileType, null: true

  def resolve(file_attributes:)
    printfile = Printfile.new(file_attributes.to_h)
    if printfile.save!
      { printfile: printfile }
    else
      { printfile: nil }
    end
  end
end