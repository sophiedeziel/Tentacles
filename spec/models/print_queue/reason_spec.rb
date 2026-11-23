# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Reason do
  let(:reason) { described_class.new(code: :wrong_material, message: 'Needs PLA, PETG is loaded here') }

  it 'keeps its code as a symbol and its message as a string' do
    expect(reason.to_h).to eq(code: :wrong_material, message: 'Needs PLA, PETG is loaded here')
  end

  it 'is read-only' do
    expect { reason.save }.to raise_error(ApplicationModel::ReadOnlyRecord)
  end
end
