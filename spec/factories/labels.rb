# frozen_string_literal: true

FactoryBot.define do
  factory :label, class: 'Library::Label' do
    name { 'My red label' }
    color { '#ff0000' }
  end
end
