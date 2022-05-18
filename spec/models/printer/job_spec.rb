# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Job, type: :model do
  it 'has a valid factory' do
    expect(build(:printer_job)).to be_valid
  end
end
