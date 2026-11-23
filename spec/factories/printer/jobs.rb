# frozen_string_literal: true

FactoryBot.define do
  factory :printer_job, class: 'Printer::Job' do
    executable { build(:file_record) }
    printer { build(:printer) }

    # A copy of a global queue entry, printing its file
    trait :copy do
      print_job
      executable { print_job.item }
      copy_number { print_job.next_copy_number }
    end
  end
end
