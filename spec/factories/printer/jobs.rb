# frozen_string_literal: true

FactoryBot.define do
  factory :printer_job, class: 'Printer::Job' do
    executable { build(:file_record) }
    printer { build(:printer) }
  end
end
