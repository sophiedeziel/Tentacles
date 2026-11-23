# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::Widget do
  let(:section) { Dashboard::Section.create!(title: nil, position: 0) }
  let(:printer) { create(:printer) }

  def printer_widget(**attributes)
    Dashboard::PrinterWidget.new(section: section, printer:, width_units: 2, height_units: 1, position: 0, **attributes)
  end

  def queue_widget(**attributes)
    Dashboard::PrintQueueWidget.new(section: section, width_units: 4, height_units: 2, position: 0, **attributes)
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
    it "destroys the printer's widgets when the printer is deleted" do
      printer_widget.save!
      queue_widget(printer:).save!
      all_printers = queue_widget(position: 1).tap(&:save!)

      expect { printer.destroy! }.to change(described_class, :count).from(3).to(1)
      expect(described_class.sole).to eq(all_printers)
    end
  end
end
