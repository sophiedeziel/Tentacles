# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::PrinterReady do
  include_context 'with a queue operation'

  let(:printer) { create(:printer) }

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(printer:) }
  end

  it 'asks for a dispatch pass, without a push' do
    expect(described_class.new(printer:).save).to be true

    expect_dispatch_requested
    expect(PrintQueue).not_to have_received(:push_changed)
  end

  it "leaves the printer's active copy to its spool" do
    copy = create(:printer_job, :copy, printer:, status: 'active', started_at: 1.hour.ago)

    described_class.new(printer:).save

    expect(copy.reload).to have_attributes(status: 'active', finished_at: nil)
  end

  it 'is refused without a printer' do
    expect_refused(described_class.new(printer: nil), "Printer can't be blank")
  end
end
