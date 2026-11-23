# frozen_string_literal: true

require 'rails_helper'
require_relative 'queue_mutation_context'

RSpec.describe Mutations::Queue::ConfirmBedCleared, type: :request do
  include_context 'with a queue mutation'

  let(:printer) { create(:printer, name: 'Prusa MK4') }
  let!(:last) do
    create(:printer_job, :copy, printer:, status: 'completed', started_at: 2.hours.ago, finished_at: 1.hour.ago)
  end

  # Bed Cleared, for the print the person was shown (the one on the bed by default)
  def confirm(printer_id = printer.id, expected_print_id: last.id)
    mutate('confirmBedCleared', { printerId: printer_id, expectedPrintId: expected_print_id },
           'printer { id } print { id bedClearedBy }')
  end

  it "stamps the printer's last print cleared by a person, pushes the printer and asks for a dispatch pass" do
    confirm

    expect_saved
    expect(data['printer']).to eq('id' => printer.id.to_s)
    expect(data['print']).to eq('id' => last.id.to_s, 'bedClearedBy' => 'PERSON')
    expect(last.reload.bed_cleared_by).to eq 'person'
    expect(TentaclesSchema.subscriptions).to have_received(:trigger).with(:print_queue_changed, {}, printer)
    expect(dispatch_request).to have_received(:save).once
  end

  it 'is refused when there is nothing to clear' do
    last.update!(bed_cleared_at: Time.current, bed_cleared_by: 'automatic')

    confirm

    expect_refused('Nothing to clear on Prusa MK4')
    expect(data['printer']).to eq('id' => printer.id.to_s)
    expect(data['print']).to be_nil
    expect_nothing_pushed
  end

  it 'returns an error for an unknown printer' do
    confirm(printer.id + 1)

    expect_refused('Printer not found')
    expect(data['printer']).to be_nil
  end
end
