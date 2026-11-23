# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::PrinterOffline do
  include_context 'with a queue operation'

  let(:printer) { create(:printer) }

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(printer:) }
  end

  it 'pushes the printer once, without asking for a dispatch pass' do
    expect(described_class.new(printer:).save).to be true

    expect_pushed_once([printer])
    expect_no_dispatch_requested
  end

  it 'is refused without a printer' do
    expect_refused(described_class.new(printer: nil), "Printer can't be blank")
  end
end
