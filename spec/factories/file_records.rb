# frozen_string_literal: true

FactoryBot.define do
  factory :file_record, class: 'FileRecord' do
    after(:build) do |post|
      post.file.attach(
        io: Rails.root.join('spec/fixture_files/test.gcode').open,
        filename: 'test.gcode',
        content_type: 'application/octet-stream'
      )
    end

    trait :only_comments do
      after(:build) do |post|
        post.file.attach(
          io: Rails.root.join('spec/fixture_files/only_comments.gcode').open,
          filename: 'test.gcode',
          content_type: 'application/octet-stream'
        )
      end
    end

    trait(:with_labels) {
      labels { build_list :label, 1 }
    }
  end
end
