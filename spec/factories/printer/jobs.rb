# frozen_string_literal: true

FactoryBot.define do
  factory :printer_job, class: 'Printer::Job' do
    executable { build(:file_manager_file) }
    printer { build(:printer) }
  end
end
