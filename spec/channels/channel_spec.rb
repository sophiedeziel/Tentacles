# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationCable::Channel, type: :channel do
  it 'exists' do
    expect(described_class).to be ApplicationCable::Channel
  end
end
