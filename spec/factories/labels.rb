# frozen_string_literal: true

FactoryBot.define do
  factory :label, class: 'Library::Label' do
    name { 'My red label' }
    color { '#ff0000' }

    trait(:with_files) do
      items { build_list :file_record, 1 }
    end
  end
end
