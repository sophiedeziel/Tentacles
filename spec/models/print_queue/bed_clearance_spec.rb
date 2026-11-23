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

  # Bed Cleared, for the print the person was shown
  def clearance(expected = printer.bed_to_clear)
    described_class.new(printer:, expected_print_id: expected&.id)
  end

  def clear(expected = printer.bed_to_clear)
    clearance(expected).tap(&:save)
  end

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(printer:, expected_print_id: finished_copy(1.hour.ago).id) }
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

    it 'pushes the printer once and asks for a dispatch pass' do
      clear

      expect_pushed_once([printer])
      expect_dispatch_requested
    end
  end

  context 'when the bed holds another print than the one the person was shown' do
    # They were shown the older copy; it was cleared, then a newer one finished on the bed
    let!(:seen) { finished_copy(3.hours.ago, bed_cleared_at: 2.hours.ago, bed_cleared_by: 'automatic') }
    let!(:newer) { finished_copy(1.hour.ago) }

    it 'is refused, naming the print on the bed, and clears nothing' do
      expect_refused(clearance(seen),
                     "Prusa MK4's bed now holds another print: test.gcode, copy 2 of 3. Check it before " \
                     'clearing the bed.')
      expect(newer.reload).to have_attributes(bed_cleared_at: nil, bed_cleared_by: nil)
    end

    it 'names the file alone for a single copy' do
      entry.update!(copies: 1)

      expect_refused(clearance(seen),
                     "Prusa MK4's bed now holds another print: test.gcode. Check it before clearing the bed.")
    end

    it "is refused for a print that is not this printer's" do
      other = create(:printer_job, :copy, print_job: entry, printer: create(:printer), status: 'completed',
                                          started_at: 2.hours.ago, finished_at: 1.hour.ago)

      expect(clear(other).errors[:base].first).to start_with "Prusa MK4's bed now holds another print"
    end
  end

  # The write checks again under the queue's lock: a newer print can finish between the check and the write
  it 'is refused when a newer print finishes while it is saved' do
    seen = finished_copy(2.hours.ago)
    clearance = clearance(seen)
    allow(PrintQueue::Setting).to receive(:lock_current).and_wrap_original do |original|
      seen.update!(bed_cleared_at: 90.minutes.ago, bed_cleared_by: 'automatic')
      finished_copy(1.hour.ago)
      original.call
    end

    expect(clearance.save).to be false
    expect(clearance.errors[:base].first).to start_with "Prusa MK4's bed now holds another print"
    expect(printer.reload.bed_to_clear).to have_attributes(bed_cleared_at: nil)
    expect(PrintQueue).not_to have_received(:push_changed)
  end

  context 'when there is nothing to clear' do
    # The print the person was shown, cleared since
    let(:seen) { finished_copy(3.hours.ago, bed_cleared_at: 2.hours.ago, bed_cleared_by: 'automatic') }

    it 'is refused while the last print is under way' do
      under_way = copy(status: 'active', started_at: 1.hour.ago)

      expect_refused(clearance(seen), 'Nothing to clear on Prusa MK4')
      expect(under_way.reload.bed_cleared_at).to be_nil
    end

    it 'is refused when the print it was shown was already cleared' do
      expect_refused(clearance(seen), 'Nothing to clear on Prusa MK4')
      expect(seen.reload).to have_attributes(bed_cleared_by: 'automatic')
    end
  end

  it 'is refused without a printer or the print the person was shown' do
    expect_refused(described_class.new(printer: nil, expected_print_id: nil), "Printer can't be blank",
                   "Expected print can't be blank")
  end
end
