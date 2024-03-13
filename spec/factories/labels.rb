FactoryBot.define do
  factory :label do
    name { 'My red label' }
    color { '#ff0000' }

    trait(:with_files) {
      file_records { build_list :file_record, 1 }
    }
  end
end
