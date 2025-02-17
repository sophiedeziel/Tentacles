# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  it 'exists' do
    expect(described_class).to be < ActionCable::Connection::Base
  end
end
