require 'rails_helper'

RSpec.describe GraphqlChannel, type: :channel do
  it 'exists' do
    expect(described_class).to be < ApplicationCable::Channel
  end
end
