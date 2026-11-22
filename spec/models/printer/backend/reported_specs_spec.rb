# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Backend::ReportedSpecs do
  it 'casts the reported values to the types of the Printer::Specs columns' do
    specs = described_class.new(name: 'Prusa MK4', nozzle_diameter: '0.4', extruders: '1', heated_bed: 'true',
                                materials: ['PLA', :PETG])

    expect(specs).to have_attributes(name: 'Prusa MK4', nozzle_diameter: 0.4, extruders: 1, heated_bed: true,
                                     materials: %w[PLA PETG])
  end

  it 'is nil for what the server does not report' do
    expect(described_class.new(model: 'MK4').attributes.compact).to eq('model' => 'MK4')
  end

  it 'is read-only' do
    specs = described_class.new(model: 'MK4')

    expect(specs).to be_readonly
    expect { specs.save }.to raise_error(ApplicationModel::ReadOnlyRecord)
  end
end
