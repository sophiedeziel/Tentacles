# frozen_string_literal: true

FactoryBot.define do
  factory :print_job, class: 'PrintQueue::Job' do
    item factory: :file_record
    sequence(:position)
  end

  factory :print_job_printer, class: 'PrintQueue::JobPrinter' do
    job factory: :print_job
    printer
  end

  factory :print_queue_setting, class: 'PrintQueue::Setting' do
    id { PrintQueue::Setting::ID }
  end
end
