# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::DispatchResumption do
  include_context 'with a queue operation'

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new }
  end

  it 'resumes dispatch' do
    PrintQueue::Setting.current.update!(dispatch_paused: true)

    expect(described_class.new.save).to be true
    expect(PrintQueue::Setting.dispatch_paused?).to be false
  end

  it 'pushes once, with no printer, and asks for a dispatch pass' do
    described_class.new.save

    expect_pushed_once([])
    expect_dispatch_requested
  end
end
