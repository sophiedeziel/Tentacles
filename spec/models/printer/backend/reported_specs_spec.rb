# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Backend::ReportedSpecs do
  it 'is read-only' do
    specs = described_class.new(model: 'MK4')

    expect(specs).to be_readonly
    expect { specs.save }.to raise_error(ApplicationModel::ReadOnlyRecord)
  end
end
