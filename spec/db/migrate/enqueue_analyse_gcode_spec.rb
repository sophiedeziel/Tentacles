# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261122150000_enqueue_analyse_gcode')

RSpec.describe EnqueueAnalyseGcode do
  let(:migration) { described_class.new.tap { |migration| migration.verbose = false } }

  describe '#up' do
    it 'creates a pending row and enqueues one AnalyseGcodeJob per G-code file' do
      items = create_list(:file_record, 2)

      expect { migration.up }.to have_enqueued_job(AnalyseGcodeJob).exactly(2).times
      items.each do |item|
        expect(AnalyseGcodeJob).to have_been_enqueued.with(item.id)
        expect(item.reload.gcode_summary).to have_attributes(status: 'pending', analysis_version: 0)
      end
    end

    it 'leaves out the files that are not G-code' do
      stl = build(:file_record)
      stl.file.attach(io: StringIO.new('solid cube'), filename: 'cube.stl')
      stl.save!

      expect { migration.up }.not_to have_enqueued_job(AnalyseGcodeJob)
      expect(stl.reload.gcode_summary).to be_nil
    end

    it 'keeps the row a file already has, so that it can run again' do
      summary = create(:gcode_summary, :ready)

      expect { migration.up }.not_to change(Library::GcodeSummary, :count)
      expect(summary.reload).to be_ready
    end

    it 'lets the migration finish when Redis is down' do
      create(:file_record)
      allow(AnalyseGcodeJob).to receive(:perform_later).and_raise(RedisClient::CannotConnectError, 'refused')

      expect { migration.up }.not_to raise_error
    end
  end
end
