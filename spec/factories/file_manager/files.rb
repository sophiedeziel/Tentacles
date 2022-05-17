FactoryBot.define do
  factory :file_manager_file, class: 'FileManager::File' do
    after(:build) do |post|
      post.file.attach(
        io: File.open(Rails.root.join('spec/fixture_files/test.gcode')),
        filename: 'test.gcode',
        content_type: 'application/octet-stream'
      )
    end
  end
end
