# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261116100000_enqueue_fill_printer_specs')

RSpec.describe EnqueueFillPrinterSpecs do
  let(:migration) { described_class.new.tap { |migration| migration.verbose = false } }

  describe '#up' do
    it 'enqueues one FillPrinterSpecsJob per printer' do
      printers = create_list(:printer, 2)

      expect { migration.up }.to have_enqueued_job(FillPrinterSpecsJob).exactly(2).times
      printers.each { |printer| expect(FillPrinterSpecsJob).to have_been_enqueued.with(printer.id) }
    end

    it 'enqueues nothing without printers' do
      expect { migration.up }.not_to have_enqueued_job(FillPrinterSpecsJob)
    end

    it 'lets the migration finish when Redis is down' do
      create(:printer)
      allow(FillPrinterSpecsJob).to receive(:perform_later).and_raise(RedisClient::CannotConnectError, 'refused')

      expect { migration.up }.not_to raise_error
    end
  end
end
