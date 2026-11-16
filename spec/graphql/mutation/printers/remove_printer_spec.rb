# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Printers::RemovePrinter, type: :request do
  let(:redis) { MockRedis.new.tap { |redis| redis.define_singleton_method(:publish) { |_channel, _message| 0 } } }
  let(:subscriptions) { TentaclesSchema.subscriptions }
  let(:printer) { create(:printer) }
  let(:file) { create(:file_record) }
  let(:data) { response.parsed_body.dig('data', 'removePrinter') }
  let(:query) do
    <<~GQL
      mutation removePrinter($input: RemovePrinterInput!) {
        removePrinter(input: $input) { removedPrinterId errors }
      }
    GQL
  end

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(redis).to receive(:publish).and_call_original
    allow(subscriptions).to receive(:trigger)
  end

  def remove_printer(id)
    post '/graphql', params: { query:, variables: { input: { id: } } }
  end

  context 'with a printer that has jobs, widgets and a monitor snapshot' do
    let(:section) { DashboardSection.create!(title: nil, position: 0) }
    let(:triggers) { [] }

    before do
      %w[enqueued active completed].each { |status| create(:printer_job, printer:, executable: file, status:) }
      PrinterWidget.create!(dashboard_section: section, printer:, width_units: 2, height_units: 1, position: 0)
      PrinterStatusStore.write(PrinterStatus.unknown(printer_id: printer.id, last_seen_at: nil))
      allow(subscriptions).to receive(:trigger) { |*args| triggers << args.first }
      remove_printer(printer.id)
    end

    it 'returns the id of the removed printer' do
      expect(response.parsed_body['errors']).to be_nil
      expect(data).to eq('removedPrinterId' => printer.id.to_s, 'errors' => [])
    end

    it 'removes the printer, its jobs, its widgets and its snapshot, and keeps its files' do
      expect(Printer.exists?(printer.id)).to be false
      expect(Printer::Job.where(printer_id: printer.id)).to be_empty
      expect(DashboardWidget.where(printer_id: printer.id)).to be_empty
      expect(PrinterStatusStore.read(printer.id)).to be_nil
      expect(FileRecord.exists?(file.id)).to be true
    end

    it 'pushes printQueueChanged and dashboardChanged once each' do
      expect(triggers).to contain_exactly(:print_queue_changed, :dashboard_changed)
    end

    it 'tells the spooler' do
      expect(redis).to have_received(:publish)
        .with('printers', { command: 'remove_printer', printer_id: printer.id }.to_json)
    end
  end

  context 'with an unknown id' do
    it 'returns an error and removes nothing' do
      printer
      expect { remove_printer(printer.id + 1) }.not_to(change { Printer.count })

      expect(data).to eq('removedPrinterId' => nil, 'errors' => ['Printer not found'])
      expect(subscriptions).not_to have_received(:trigger)
      expect(redis).not_to have_received(:publish)
    end
  end

  context 'when the printer changes while it is removed' do
    before { allow(Printers::Remove).to receive(:call).and_raise(ActiveRecord::InvalidForeignKey) }

    it 'returns an error' do
      remove_printer(printer.id)

      expect(data).to eq('removedPrinterId' => nil, 'errors' => ['The printer changed while removing it, try again'])
    end
  end
end
