# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Bed do
  let(:entry) { create(:print_job, copies: 10) }

  # A printer with these jobs, created in order: copies of the entry, or jobs of its own queue (`own: true`)
  def printer_with(*jobs)
    create(:printer).tap do |printer|
      jobs.each do |job|
        attributes = job.except(:own)
        next create(:printer_job, printer:, **attributes) if job[:own]

        create(:printer_job, :copy, print_job: entry, printer:, **attributes)
      end
    end
  end

  def finished(at = 1.hour.ago, **attributes)
    { status: 'completed', started_at: at - 1.hour, finished_at: at, **attributes }
  end

  def under_way(at = 1.hour.ago)
    { status: 'active', started_at: at }
  end

  # A copy cancelled before its spool started it: it never had a started_at
  def cancelled_before_start
    { status: 'cancelled', finished_at: Time.current, cancel_requested_at: Time.current }
  end

  # A job of the printer's own queue, from before the global queue: no started_at
  def old_job
    { own: true, status: 'completed' }
  end

  describe '#bed_needs_clearing? and #bed_to_clear' do
    it 'is false for a printer that never printed' do
      printer = printer_with

      expect(printer.bed_needs_clearing?).to be false
      expect(printer.bed_to_clear).to be_nil
    end

    it 'is true when the last started print finished and its bed was not cleared' do
      printer = printer_with(finished)

      expect(printer.bed_needs_clearing?).to be true
      expect(printer.bed_to_clear).to eq printer.jobs.sole
    end

    it 'is false once the bed is cleared' do
      printer = printer_with(finished(bed_cleared_at: Time.current, bed_cleared_by: 'person'))

      expect(printer.bed_needs_clearing?).to be false
      expect(printer.bed_to_clear).to be_nil
    end

    it 'is false while the last started print is under way' do
      expect(printer_with(finished, under_way(1.minute.ago)).bed_needs_clearing?).to be false
    end

    it 'is false for a copy cancelled before it started' do
      expect(printer_with(cancelled_before_start).bed_needs_clearing?).to be false
    end

    it 'ignores a later copy cancelled before it started: the earlier print is still on the bed' do
      printer = printer_with(finished, cancelled_before_start)

      expect(printer.bed_needs_clearing?).to be true
      expect(printer.bed_to_clear).to eq printer.jobs.first
    end

    it 'is true for a copy cancelled after it started: its print stays on the bed' do
      printer = printer_with(finished(status: 'cancelled', cancel_requested_at: 70.minutes.ago))

      expect(printer.bed_needs_clearing?).to be true
    end

    it 'is false for old jobs, which never have a started_at' do
      expect(printer_with(old_job).bed_needs_clearing?).to be false
    end

    it 'reads the most recently started print, whatever the order the jobs were created in' do
      cleared = finished(10.minutes.ago, bed_cleared_at: Time.current, bed_cleared_by: 'person')

      expect(printer_with(cleared, finished(2.hours.ago)).bed_needs_clearing?).to be false
      expect(printer_with(finished(10.minutes.ago), cleared.merge(started_at: 3.hours.ago)).bed_needs_clearing?)
        .to be true
    end

    it 'breaks a started_at tie with the last created job' do
      at = 1.hour.ago.change(usec: 0)

      expect(printer_with(finished(started_at: at), under_way(at)).bed_needs_clearing?).to be false
      expect(printer_with(under_way(at), finished(started_at: at)).bed_needs_clearing?).to be true
    end
  end

  describe '.beds_to_clear' do
    it 'returns nothing without a query for no printers' do
      allow(Printer::Job).to receive(:where).and_call_original

      expect(Printer.beds_to_clear([])).to eq({})
      expect(Printer::Job).not_to have_received(:where)
    end

    it 'gives the print on the bed of each printer that has one, by printer id, agreeing with #bed_to_clear' do
      to_clear = printer_with(finished(2.hours.ago), finished)
      cleared = printer_with(finished(bed_cleared_at: Time.current, bed_cleared_by: 'person'))
      printing = printer_with(finished, under_way(1.minute.ago))

      expect(Printer.beds_to_clear([to_clear, cleared, printing].map(&:id))).to eq(to_clear.id => to_clear.bed_to_clear)
    end
  end

  describe '.ids_with_bed_to_clear' do
    it 'returns an empty set without a query for no printers' do
      allow(Printer::Job).to receive(:where).and_call_original

      expect(Printer.ids_with_bed_to_clear([])).to eq Set.new
      expect(Printer::Job).not_to have_received(:where)
    end

    it 'agrees with #bed_needs_clearing? for every case' do
      at = 1.hour.ago.change(usec: 0)
      cleared = finished(bed_cleared_at: Time.current, bed_cleared_by: 'person')
      printers = [
        printer_with,
        printer_with(finished),
        printer_with(cleared),
        printer_with(finished, under_way(1.minute.ago)),
        printer_with(cancelled_before_start),
        printer_with(finished, cancelled_before_start),
        printer_with(finished(status: 'cancelled')),
        printer_with(old_job),
        printer_with(old_job, finished),
        printer_with(finished(10.minutes.ago, **cleared.except(:finished_at)), finished(2.hours.ago)),
        printer_with(finished(10.minutes.ago), cleared.merge(started_at: 3.hours.ago)),
        printer_with(finished(started_at: at), under_way(at)),
        printer_with(under_way(at), finished(started_at: at))
      ]
      ids = printers.map(&:id)

      expected = printers.select(&:bed_needs_clearing?).to_set(&:id)
      expect(Printer.ids_with_bed_to_clear(ids)).to eq expected
      expect(expected.size).to eq 6
    end

    it 'only considers the printers given' do
      given = printer_with(finished)
      printer_with(finished)

      expect(Printer.ids_with_bed_to_clear([given.id])).to eq Set[given.id]
    end
  end
end
