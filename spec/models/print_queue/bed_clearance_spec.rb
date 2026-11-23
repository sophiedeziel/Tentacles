# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::BedClearance do
  include_context 'with a queue operation'

  let(:printer) { create(:printer, name: 'Prusa MK4') }
  let(:entry) { create(:print_job, copies: 3) }

  # A copy of the entry on the printer
  def copy(**attributes)
    create(:printer_job, :copy, print_job: entry, printer:, **attributes)
  end

  # A copy that started, then finished at this time
  def finished_copy(at, **attributes)
    copy(status: 'completed', started_at: at - 1.hour, finished_at: at, **attributes)
  end

  def clear
    described_class.new(printer:).tap(&:save)
  end

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(printer:) }
  end

  context 'when the last print is on the bed' do
    let!(:older) { finished_copy(3.hours.ago) }
    let!(:last) { finished_copy(1.hour.ago) }

    it 'stamps it cleared by a person' do
      clearance = clear

      expect(clearance.errors).to be_empty
      expect(clearance.printer_job).to eq last
      expect(last.reload).to have_attributes(bed_cleared_at: be_within(1.second).of(Time.current),
                                             bed_cleared_by: 'person')
    end

    it 'leaves the older prints alone' do
      clear

      expect(older.reload).to have_attributes(bed_cleared_at: nil, bed_cleared_by: nil)
    end

    it 'leaves the printer with nothing to clear' do
      clear

      expect(printer.bed_needs_clearing?).to be false
    end

    it 'pushes the printer once and asks for a dispatch pass' do
      clear

      expect_pushed_once([printer])
      expect_dispatch_requested
    end
  end

  context 'when there is nothing to clear' do
    it 'is refused for a printer that never printed' do
      expect_refused(described_class.new(printer:), 'Nothing to clear on Prusa MK4')
    end

    it 'is refused while the last print is under way' do
      finished_copy(3.hours.ago)
      under_way = copy(status: 'active', started_at: 1.hour.ago)

      expect_refused(described_class.new(printer:), 'Nothing to clear on Prusa MK4')
      expect(under_way.reload.bed_cleared_at).to be_nil
    end

    it 'is refused when the last print was already cleared' do
      cleared_at = 30.minutes.ago.change(usec: 0)
      last = finished_copy(1.hour.ago, bed_cleared_at: cleared_at, bed_cleared_by: 'automatic')

      expect_refused(described_class.new(printer:), 'Nothing to clear on Prusa MK4')
      expect(last.reload).to have_attributes(bed_cleared_at: cleared_at, bed_cleared_by: 'automatic')
    end
  end

  it 'is refused without a printer' do
    expect_refused(described_class.new(printer: nil), "Printer can't be blank")
  end
end
