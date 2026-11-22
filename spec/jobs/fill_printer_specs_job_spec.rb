# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FillPrinterSpecsJob, type: :job do
  describe '#perform' do
    let(:printer) { create(:printer, name: 'Prusa MK4') }

    before do
      allow(Printer).to receive(:find_by).and_call_original
      allow(Printer).to receive(:find_by).with(id: printer.id).and_return(printer)
      allow(Rails.logger).to receive(:info)
    end

    it 'fills the blank specs from the server, and logs the columns filled' do
      allow(printer).to receive(:fill_specs_from_server).and_return(%w[model firmware])

      described_class.perform_now(printer.id)

      expect(printer).to have_received(:fill_specs_from_server)
      expect(Rails.logger).to have_received(:info)
        .with("[FillPrinterSpecsJob] Prusa MK4 (##{printer.id}): filled model, firmware")
    end

    it 'logs that there was nothing to fill' do
      allow(printer).to receive(:fill_specs_from_server).and_return([])

      described_class.perform_now(printer.id)

      expect(Rails.logger).to have_received(:info)
        .with("[FillPrinterSpecsJob] Prusa MK4 (##{printer.id}): nothing to fill")
    end

    it 'logs that the server could not be read, without raising' do
      allow(printer).to receive(:fill_specs_from_server).and_return(nil)

      expect { described_class.perform_now(printer.id) }.not_to raise_error
      expect(Rails.logger).to have_received(:info)
        .with("[FillPrinterSpecsJob] Prusa MK4 (##{printer.id}): the server could not be read, nothing filled")
    end

    it 'saves when it read the server, so that the monitor does not enqueue it again' do
      allow(printer).to receive(:reported_specs).and_return(Printer::Backend::ReportedSpecs.new(model: 'MK4'))

      described_class.perform_now(printer.id)

      expect(printer.reload).to have_attributes(model: 'MK4', specs_filled_at: be_within(1.second).of(Time.current))
    end

    it 'leaves specs_filled_at nil when the server could not be read' do
      allow(printer).to receive(:reported_specs).and_return(nil)

      described_class.perform_now(printer.id)

      expect(printer.reload.specs_filled_at).to be_nil
    end

    it 'does nothing when the printer was removed since' do
      expect { described_class.perform_now(printer.id + 1) }.not_to raise_error
      expect(Rails.logger).not_to have_received(:info).with(/FillPrinterSpecsJob/)
    end
  end
end
