# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::TakesJobsChange do
  let(:printer) { create(:printer) }
  let(:dispatch_request) { instance_spy(PrintQueue::DispatchRequest, save: true) }

  before do
    allow(PrintQueue).to receive(:enabled?).and_return(true)
    allow(PrintQueue).to receive(:push_changed)
    allow(PrintQueue::DispatchRequest).to receive(:new).and_return(dispatch_request)
  end

  def change(takes_jobs)
    described_class.new(printer:, takes_jobs:).tap(&:save)
  end

  it 'turns taking jobs off, pushes the printer once and asks for no dispatch pass' do
    expect(change(false).errors).to be_empty

    expect(printer.reload.takes_jobs).to be false
    expect(PrintQueue).to have_received(:push_changed).once.with([printer])
    expect(dispatch_request).not_to have_received(:save)
  end

  it 'turns taking jobs on, pushes the printer and asks for a dispatch pass' do
    printer.update!(takes_jobs: false)

    expect(change(true).errors).to be_empty

    expect(printer.reload.takes_jobs).to be true
    expect(PrintQueue).to have_received(:push_changed).once.with([printer])
    expect(dispatch_request).to have_received(:save).once
  end

  it 'pushes nothing when the value does not change' do
    expect(change(true).errors).to be_empty

    expect(PrintQueue).not_to have_received(:push_changed)
    expect(dispatch_request).not_to have_received(:save)
  end

  it 'is refused while the global queue is off' do
    allow(PrintQueue).to receive(:enabled?).and_return(false)

    expect(change(false).errors.full_messages).to eq ['The global print queue is off']
    expect(printer.reload.takes_jobs).to be true
    expect(PrintQueue).not_to have_received(:push_changed)
  end

  it "returns the printer's validation errors" do
    printer.update_column(:bed_shape, 'hexagonal') # rubocop:disable Rails/SkipsModelValidations

    expect(change(false).errors.full_messages).to eq ['Validation failed: Bed shape is not included in the list']
    expect(printer.reload.takes_jobs).to be true
  end
end
