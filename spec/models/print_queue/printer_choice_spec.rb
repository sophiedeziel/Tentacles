# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::PrinterChoice do
  # A PLA file whose footprint is 123.09 × 130 mm, 15 mm high
  let(:needs) do
    job = create(:print_job)
    create(:gcode_summary, :ready, :with_tools, item: job.item, materials: ['PLA'])
    job.needs
  end
  let(:mk4) { create(:printer, name: 'Prusa MK4', build_volume_x: 250, build_volume_y: 210) }
  let(:mini) { create(:printer, name: 'Mini Delta', bed_shape: 'circular', build_diameter: 110) }

  def choice(**attributes) = described_class.new(needs:, **attributes)

  it 'refuses nothing, and lists no printer, for every printer that can print it' do
    expect(choice(all_capable: true, printer_ids: [mini.id])).to have_attributes(refusal: nil, printers: [])
  end

  it 'lists the printers chosen, once each (ids may be strings)' do
    chosen = choice(all_capable: false, printer_ids: [mk4.id.to_s, mk4.id, ''])

    expect(chosen).to have_attributes(refusal: nil, printers: [mk4])
  end

  it 'refuses an empty list' do
    expect(choice(all_capable: false, printer_ids: []).refusal).to eq 'Choose at least one printer'
  end

  it 'refuses a printer that no longer exists' do
    expect(choice(all_capable: false, printer_ids: [mk4.id, 0]).refusal)
      .to eq 'One of the printers chosen no longer exists'
  end

  it 'refuses a printer that can never print it, with why' do
    expect(choice(all_capable: false, printer_ids: [mk4.id, mini.id]).refusal)
      .to eq "Mini Delta can't print it: Bed too small: needs 123.09 × 130 mm, has a 110 mm round bed"
  end

  it 'does not refuse a printer without the filament loaded, nor an offline one' do
    create(:printer_loaded_filament, printer: mk4, material: 'PETG', colour: 'Grey')

    expect(choice(all_capable: false, printer_ids: [mk4.id]).refusal).to be_nil
  end

  it 'does not refuse for a value that is not known' do
    unknown = PrintQueue::Needs.new
    expect(described_class.new(needs: unknown, all_capable: false, printer_ids: [mini.id]).refusal).to be_nil
  end
end
