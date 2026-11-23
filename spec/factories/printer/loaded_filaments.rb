# frozen_string_literal: true

FactoryBot.define do
  factory :printer_loaded_filament, class: 'Printer::LoadedFilament' do
    printer { build(:printer) }
    material { 'PLA' }
    colour { 'Black' }
  end
end
