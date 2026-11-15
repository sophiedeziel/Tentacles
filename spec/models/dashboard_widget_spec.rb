# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardWidget do
  let(:section) { DashboardSection.create!(title: nil, position: 0) }
  let(:printer) { create(:printer) }

  def printer_widget(**attributes)
    PrinterWidget.new(dashboard_section: section, printer:, width_units: 2, height_units: 1, position: 0, **attributes)
  end

  def queue_widget(**attributes)
    PrintQueueWidget.new(dashboard_section: section, width_units: 4, height_units: 2, position: 0, **attributes)
  end

  def errors_of(widget)
    widget.validate
    widget.errors.full_messages
  end

  describe 'spans' do
    it 'allows 1×1, 2×1, 2×2 and 4×2 for a printer' do
      [[1, 1], [2, 1], [2, 2], [4, 2]].each do |width, height|
        expect(printer_widget(width_units: width, height_units: height)).to be_valid
      end
      expect(errors_of(printer_widget(width_units: 4, height_units: 4)))
        .to eq(["4×4 isn't a size this widget supports"])
    end

    it 'also allows 4×4 for a print queue' do
      [[1, 1], [2, 1], [2, 2], [4, 2], [4, 4]].each do |width, height|
        expect(queue_widget(width_units: width, height_units: height)).to be_valid
      end
      expect(errors_of(queue_widget(width_units: 1, height_units: 2))).to eq(["1×2 isn't a size this widget supports"])
    end

    it 'are whole numbers from 1 to 4' do
      expect(errors_of(queue_widget(width_units: 5, height_units: 2))).to include('Width units must be in 1..4')
      expect(errors_of(queue_widget(width_units: 4, height_units: 1.5))).to include('Height units must be an integer')
    end
  end

  describe 'options' do
    it 'read as the defaults when missing' do
      expect(printer_widget).to have_attributes(camera: true, time_left: true, temperatures: true, up_next: true,
                                                controls: true)
      expect(queue_widget).to have_attributes(now_printing: true, start_next: true, row_per_printer: false,
                                              history: false)
    end

    it 'are written as booleans in the json column' do
      widget = queue_widget
      widget.history = '1'
      widget.start_next = false
      widget.save!

      expect(widget.reload.options).to eq('history' => true, 'start_next' => false)
      expect(widget).to have_attributes(history: true, start_next: false, now_printing: true)
    end

    it "are kept for every size, even those that don't show them" do
      widget = printer_widget(width_units: 4, height_units: 2, options: { 'camera' => true })
      widget.save!
      widget.update!(width_units: 1, height_units: 1)

      expect(widget.reload.camera).to be(true)
    end

    it "reject keys the type didn't declare" do
      expect(errors_of(printer_widget(options: { 'history' => true, 'foo' => false })))
        .to eq(['Options unknown: history, foo'])
    end

    it 'are booleans' do
      expect(errors_of(queue_widget(options: { 'history' => 'yes', 'start_next' => nil })))
        .to eq(['Options must be true or false: history, start_next'])
    end

    it 'are an object' do
      expect(errors_of(queue_widget(options: [true]))).to eq(['Options must be an object'])
    end
  end

  describe 'printer' do
    it 'is required for a printer widget' do
      expect(errors_of(printer_widget(printer: nil))).to eq(["Printer can't be blank"])
    end

    it 'is optional for a print queue (all printers)' do
      expect(queue_widget(printer: nil)).to be_valid
      expect(queue_widget(printer:)).to be_valid
    end

    it "destroys the printer's widgets when the printer is deleted" do
      printer_widget.save!
      queue_widget(printer:).save!
      all_printers = queue_widget(position: 1).tap(&:save!)

      expect { printer.destroy! }.to change(described_class, :count).from(3).to(1)
      expect(described_class.sole).to eq(all_printers)
    end
  end

  it 'is a known type' do
    widget = described_class.new(dashboard_section: section, width_units: 1, height_units: 1, position: 0)

    expect(errors_of(widget)).to include('Type is not included in the list')
  end
end
