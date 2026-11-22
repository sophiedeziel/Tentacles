# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardSection do
  include ActiveSupport::Testing::TimeHelpers

  let(:printer) { create(:printer, name: 'Prusa MK4') }

  def tree
    described_class.includes(:widgets).map do |section|
      [section.title, section.widgets.map { |widget| [widget.type, widget.width_units, widget.height_units] }]
    end
  end

  describe 'validation' do
    it 'has no title for the first section' do
      expect(described_class.new(position: 0)).to be_valid
      section = described_class.new(position: 0, title: 'Top')

      expect(section).not_to be_valid
      expect(section.errors.full_messages).to eq(['Title must be empty for the first section'])
    end

    it 'has a non-blank title of at most 100 characters for a divider' do
      expect(described_class.new(position: 1, title: 'Garage')).to be_valid
      [nil, '', '   ', 'x' * 101].each do |title|
        expect(described_class.new(position: 1, title:)).not_to be_valid
      end
    end
  end

  describe '.build_default' do
    it 'is one untitled section with a Print Queue XL for all printers, then a Printer M per printer' do
      first = create(:printer)
      second = create(:printer)

      sections = described_class.build_default

      expect(sections.size).to eq(1)
      expect(sections.first).to have_attributes(id: nil, title: nil, position: 0)
      expect(sections.first.widgets.map { |widget| [widget.class, widget.width_units, widget.height_units] })
        .to eq([[PrintQueueWidget, 4, 2], [PrinterWidget, 2, 1], [PrinterWidget, 2, 1]])
      expect(sections.first.widgets.map(&:printer)).to eq([nil, first, second])
      expect(sections.first.widgets.map(&:position)).to eq([0, 1, 2])
    end

    it 'turns the cameras off and keeps the other defaults' do
      printer
      queue, printer_widget = described_class.build_default.first.widgets

      expect(printer_widget).to have_attributes(id: nil, camera: false, time_left: true, controls: true)
      expect(queue).to have_attributes(id: nil, now_printing: true, start_next: true)
    end

    it 'shows one row per printer and the history in the Print Queue' do
      queue = described_class.build_default.first.widgets.first

      expect(queue).to have_attributes(row_per_printer: true, history: true)
    end

    it 'saves nothing' do
      printer

      expect { described_class.build_default }.not_to change(DashboardWidget, :count)
    end

    it 'leaves out the printers past the widget limit' do
      stub_const('DashboardSection::MAX_WIDGETS', 3)
      create_list(:printer, 3)

      expect(described_class.build_default.first.widgets.size).to eq(3)
    end
  end

  describe '.ensure_default!' do
    it 'creates the default layout when there is none' do
      printer

      expect { described_class.ensure_default! }.to change(described_class, :count).from(0).to(1)
      expect(tree).to eq([[nil, [['PrintQueueWidget', 4, 2], ['PrinterWidget', 2, 1]]]])
    end

    it 'leaves an existing layout alone' do
      described_class.create!(position: 0)

      expect { described_class.ensure_default! }.not_to change(DashboardWidget, :count)
    end

    it 'checks again under the lock, in case another request created the layout meanwhile' do
      described_class.create!(position: 0)
      allow(described_class).to receive(:exists?).and_return(false, true)
      allow(described_class).to receive(:with_layout_lock).and_call_original

      expect { described_class.ensure_default! }.not_to change(described_class, :count)
      expect(described_class).to have_received(:with_layout_lock)
    end

    it 'builds the default again when a printer is deleted while it is saved' do
      calls = 0
      allow(described_class).to receive(:build_default).and_wrap_original do |original|
        calls += 1
        calls == 1 ? [described_class.new(position: 0, title: 'Invalid')] : original.call
      end

      described_class.ensure_default!

      expect(calls).to eq(2)
      expect(described_class.count).to eq(1)
    end
  end

  describe '.with_layout_lock' do
    let(:connection) { described_class.connection }

    def lock_free?
      name = connection.quote("#{connection.current_database}:dashboard_layout")
      connection.select_value("SELECT IS_FREE_LOCK(#{name})") == 1
    end

    it "holds the database's named lock while the block runs and releases it when the block raises" do
      expect do
        described_class.with_layout_lock do
          expect(lock_free?).to be(false)
          raise 'boom'
        end
      end.to raise_error('boom')
      expect(lock_free?).to be(true)
    end

    it 'raises LockWaitTimeout when the lock stays taken' do
      allow(connection).to receive(:select_value).and_call_original
      allow(connection).to receive(:select_value).with(/GET_LOCK/).and_return(0)

      expect { described_class.with_layout_lock { raise 'not run' } }.to raise_error(ActiveRecord::LockWaitTimeout)
    end
  end

  describe '.replace_all!' do
    let!(:other_printer) { create(:printer, name: 'Ender 3') }

    def widget(type, width, height, **attributes)
      { type:, width_units: width, height_units: height, options: {}, **attributes }
    end

    def replace(sections)
      described_class.replace_all!(sections)
    end

    def invalid(sections)
      expect { replace(sections) }.to raise_error(DashboardSection::InvalidLayout) { |error| return error.messages }
    end

    it 'creates rows without an id' do
      replace([{ id: nil, title: nil, widgets: [widget('PrintQueueWidget', 4, 4, options: { history: true })] },
               { id: nil, title: 'Garage', widgets: [widget('PrinterWidget', 1, 1, printer_id: printer.id.to_s)] }])

      expect(tree).to eq([[nil, [['PrintQueueWidget', 4, 4]]], ['Garage', [['PrinterWidget', 1, 1]]]])
      expect(PrintQueueWidget.sole.history).to be(true)
      expect(PrinterWidget.sole.printer).to eq(printer)
    end

    context 'with a saved layout' do
      let!(:top) { described_class.create!(position: 0) }
      let!(:garage) { described_class.create!(position: 1, title: 'Garage') }
      let!(:queue) { PrintQueueWidget.create!(dashboard_section: top, width_units: 4, height_units: 2, position: 0) }
      let!(:mk4) do
        PrinterWidget.create!(dashboard_section: garage, printer:, width_units: 2, height_units: 1, position: 0)
      end

      it 'updates rows with an id, creates the others and destroys the missing ones, ordered as given' do
        replace([
                  { id: top.id.to_s, title: nil, widgets: [
                    widget('PrinterWidget', 2, 2, id: mk4.id.to_s, printer_id: printer.id.to_s),
                    widget('PrinterWidget', 1, 1, id: nil, printer_id: other_printer.id.to_s)
                  ] },
                  { id: nil, title: 'Basement', widgets: [] }
                ])

        expect(tree).to eq([[nil, [['PrinterWidget', 2, 2], ['PrinterWidget', 1, 1]]], ['Basement', []]])
        expect(top.widgets.reload.first.id).to eq(mk4.id)
        expect(described_class.exists?(garage.id)).to be(false)
        expect(DashboardWidget.exists?(queue.id)).to be(false)
      end

      it 'rewrites the positions' do
        replace([{ id: garage.id, title: nil, widgets: [widget('PrintQueueWidget', 4, 2, id: queue.id)] },
                 { id: top.id, title: 'Was first', widgets: [] }])

        expect(garage.reload).to have_attributes(position: 0, title: nil)
        expect(top.reload).to have_attributes(position: 1, title: 'Was first')
        expect(queue.reload.dashboard_section).to eq(garage)
      end

      it 'replaces the options' do
        mk4.update!(options: { 'camera' => false, 'controls' => false })
        replace([{ id: top.id, title: nil,
                   widgets: [widget('PrinterWidget', 2, 1, id: mk4.id, printer_id: printer.id,
                                                           options: { controls: true })] }])

        expect(mk4.reload.options).to eq('controls' => true)
        expect(mk4.camera).to be(true)
      end

      it 'creates a new row for an id that no longer exists or a widget whose type changed' do
        replace([{ id: 999_999, title: nil, widgets: [widget('PrintQueueWidget', 1, 1, id: mk4.id)] }])

        expect(described_class.pluck(:id)).not_to include(999_999, top.id, garage.id)
        expect(PrintQueueWidget.sole.id).not_to eq(mk4.id)
        expect(PrinterWidget.count).to eq(0)
      end

      it 'touches the layout, even when it only removes rows' do
        travel(1.hour) do
          replace([{ id: top.id, title: nil, widgets: [widget('PrintQueueWidget', 4, 2, id: queue.id)] }])

          expect(top.reload.updated_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'reports every problem at once and saves nothing' do
        messages = invalid([
                             { id: top.id, title: 'Top', widgets: [
                               widget('PrinterWidget', 4, 4, id: mk4.id),
                               widget('CameraWidget', 1, 1)
                             ] },
                             { id: nil, title: ' ', widgets: [
                               widget('PrintQueueWidget', 1, 1, printer_id: '1 OR 1=1', options: { camera: true })
                             ] }
                           ])

        expect(messages).to eq([
                                 'Section 1: Title must be empty for the first section',
                                 "Widget 1 in section 1: 4×4 isn't a size this widget supports",
                                 "Widget 1 in section 1: Printer can't be blank",
                                 'Widget 2 in section 1: unknown type',
                                 "Section 2: Title can't be blank",
                                 "Widget 1 in section 2: printer doesn't exist",
                                 'Widget 1 in section 2: Options unknown: camera'
                               ])
        expect(tree).to eq([[nil, [['PrintQueueWidget', 4, 2]]], ['Garage', [['PrinterWidget', 2, 1]]]])
      end
    end

    describe 'limits' do
      it 'needs at least one section' do
        expect(invalid([])).to eq(['A layout needs at least one section'])
      end

      it 'stops at the limits, before loading anything' do
        sections = Array.new(51) { { id: nil, title: 'D', widgets: [widget('PrintQueueWidget', 1, 1)] * 4 } }
        allow(described_class).to receive(:with_layout_lock)

        expect(invalid(sections)).to eq(["A layout can't have more than 50 sections",
                                         "A layout can't have more than 200 widgets"])
        expect(described_class).not_to have_received(:with_layout_lock)
      end
    end
  end
end
