# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Job do
  let(:job) { create(:print_job, copies: 5) }

  # Creates a copy of `entry` with each status, in order
  def copies_with(entry, *statuses)
    statuses.each { |status| create(:printer_job, :copy, print_job: entry, status:) }
  end

  it 'has a valid factory: one copy, on any capable printer, any colour, not held' do
    entry = build(:print_job)

    expect(entry).to be_valid
    expect(entry).to have_attributes(copies: 1, held: false, same_printer: false, bound_printer: nil,
                                     all_capable: true, colour: nil, colour_key: nil)
  end

  describe 'validations' do
    it 'asks for at least one copy' do
      job.copies = 0

      expect(job).not_to be_valid
      expect(job.errors[:copies]).to eq ['must be greater than or equal to 1']
    end
  end

  describe 'colour' do
    it 'is stored as typed, trimmed, beside its key' do
      job.update!(colour: '  Galaxy  BLACK ')

      expect(job.reload).to have_attributes(colour: 'Galaxy BLACK', colour_key: 'galaxy black')
    end

    it 'is Any colour (nil, and no key) when blank or nil' do
      job.update!(colour: 'Black')

      job.update!(colour: '  ')
      expect(job.reload).to have_attributes(colour: nil, colour_key: nil)

      job.update!(colour: 'Black')
      job.update!(colour: nil)
      expect(job.reload).to have_attributes(colour: nil, colour_key: nil)
    end
  end

  describe 'printers' do
    let(:printer) { create(:printer) }

    it 'loses a printer that is deleted (the database cascades)' do
      entry = create(:print_job, all_capable: false, printers: [printer])

      Printer.where(id: printer.id).delete_all

      expect(entry.reload.printers).to be_empty
    end

    it 'is unbound when its bound printer is deleted (the database nullifies)' do
      entry = create(:print_job, same_printer: true, bound_printer: printer)

      Printer.where(id: printer.id).delete_all

      expect(entry.reload.bound_printer).to be_nil
    end

    describe '#open_to?' do
      let(:other) { create(:printer) }

      it 'is open to every printer when all capable, and to the listed ones otherwise' do
        expect(create(:print_job).open_to?(other)).to be true

        limited = create(:print_job, all_capable: false, printers: [printer])
        expect([limited.open_to?(printer), limited.open_to?(other)]).to eq [true, false]
      end

      it 'is open to the printer a same-printer batch is bound to only, and to any while it is not bound' do
        bound = create(:print_job, same_printer: true, bound_printer: printer)

        expect([bound.open_to?(printer), bound.open_to?(other)]).to eq [true, false]
        expect(create(:print_job, same_printer: true).open_to?(other)).to be true
        expect(create(:print_job, bound_printer: printer).open_to?(other)).to be true
      end
    end
  end

  describe 'copies' do
    it 'keeps its copies, as old jobs, when the entry is deleted (the database nullifies)' do
      copies_with(job, 'completed')
      copy = job.printer_jobs.first

      job.destroy!

      expect(copy.reload.print_job_id).to be_nil
    end
  end

  describe 'counts' do
    it 'are zero, with every copy waiting, before any is dispatched' do
      expect(job).to have_attributes(done_count: 0, printing_count: 0, failed_count: 0, waiting_count: 5)
      expect(job).to be_unfinished
    end

    it 'count completed copies as done, enqueued and active as printing, error and cancelled as failed' do
      copies_with(job, 'completed', 'completed', 'enqueued', 'active', 'error', 'cancelled')
      job.update!(copies: 8)

      expect(job).to have_attributes(done_count: 2, printing_count: 2, failed_count: 2, waiting_count: 2)
    end

    it 'use up a failed copy without retrying it: nothing waits once every copy is done or failed' do
      copies_with(job, 'completed', 'completed', 'completed', 'completed', 'error')

      expect(job).to have_attributes(done_count: 4, failed_count: 1, waiting_count: 0)
      expect(job).not_to be_unfinished
    end

    it 'never wait below zero copies (copies lowered below what was dispatched)' do
      copies_with(job, 'completed', 'completed')
      job.update!(copies: 1)

      expect(job.waiting_count).to eq 0
    end

    it 'are unfinished while a copy prints, even with nothing waiting' do
      job.update!(copies: 1)
      copies_with(job, 'active')

      expect(job).to have_attributes(waiting_count: 0, printing_count: 1)
      expect(job).to be_unfinished
    end

    it 'ignore the jobs of other entries and old-style jobs of the same file' do
      copies_with(create(:print_job, item: job.item), 'completed')
      create(:printer_job, executable: job.item, status: 'completed')

      expect(job.done_count).to eq 0
    end

    it 'are read once, until reload' do
      expect(job.done_count).to eq 0
      copies_with(job, 'completed')

      expect(job.done_count).to eq 0
      expect(job.reload.done_count).to eq 1
    end

    it 'are zero on an unsaved entry, without a query' do
      entry = build(:print_job, copies: 2)

      expect(entry).to have_attributes(done_count: 0, printing_count: 0, failed_count: 0, waiting_count: 2)
    end
  end

  describe '.copy_counts' do
    let(:other) { create(:print_job) }

    it 'counts the copies of many entries, zeros for one without copies' do
      copies_with(job, 'completed', 'active', 'enqueued', 'cancelled')

      expect(described_class.copy_counts([job.id, other.id])).to eq(
        job.id => { done: 1, printing: 2, failed: 1 },
        other.id => { done: 0, printing: 0, failed: 0 }
      )
    end

    it 'reads them in one query' do
      copies_with(job, 'completed')
      copies_with(other, 'error')
      queries = 0
      count_queries = ->(*) { queries += 1 }

      ActiveSupport::Notifications.subscribed(count_queries, 'sql.active_record') do
        described_class.copy_counts([job.id, other.id])
      end

      expect(queries).to eq 1
    end

    it 'is empty for no entries' do
      expect(described_class.copy_counts([])).to eq({})
    end

    it 'presets the counts of each entry, so reading them runs no query' do
      copies_with(job, 'completed', 'active')
      entries = described_class.where(id: [job.id, other.id]).to_a
      counts = described_class.copy_counts(entries.map(&:id))
      entries.each { |entry| entry.copy_counts = counts.fetch(entry.id) }
      queries = 0
      count_queries = ->(*) { queries += 1 }

      ActiveSupport::Notifications.subscribed(count_queries, 'sql.active_record') do
        expect(entries.map(&:waiting_count)).to eq [3, 1]
      end
      expect(queries).to eq 0
    end
  end

  describe '.unfinished' do
    it 'agrees with #unfinished? for every mix of copies' do
      entries = {
        waiting: create(:print_job, copies: 2),
        partly_done: create(:print_job, copies: 2).tap { |entry| copies_with(entry, 'completed') },
        printing_last: create(:print_job, copies: 1).tap { |entry| copies_with(entry, 'active') },
        done: create(:print_job, copies: 1).tap { |entry| copies_with(entry, 'completed') },
        failed: create(:print_job, copies: 2).tap { |entry| copies_with(entry, 'completed', 'error') },
        cancelled: create(:print_job, copies: 1).tap { |entry| copies_with(entry, 'cancelled') },
        lowered_while_printing: create(:print_job, copies: 1).tap do |entry|
          copies_with(entry, 'completed', 'enqueued')
        end
      }

      expect(described_class.unfinished).to match_array(entries.values.select(&:unfinished?))
      expect(described_class.unfinished.map { |entry| entries.key(entry) })
        .to contain_exactly(:waiting, :partly_done, :printing_last, :lowered_while_printing)
    end
  end

  describe '.in_queue_order' do
    it 'orders by position, then id' do
      third = create(:print_job, position: 2)
      first = create(:print_job, position: 1)
      second = create(:print_job, position: 1)

      expect(described_class.in_queue_order).to eq [first, second, third]
    end
  end

  describe '#next_copy_number' do
    it 'is 1 for the first copy, then one more than the highest' do
      expect(job.next_copy_number).to eq 1

      create(:printer_job, :copy, print_job: job, copy_number: 3)

      expect(job.next_copy_number).to eq 4
    end
  end
end
