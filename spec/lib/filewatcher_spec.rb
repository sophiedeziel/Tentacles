# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib/filewatcher')

RSpec.describe Filewatcher do
  describe 'importing a file' do
    let(:path) { Rails.root.join('tmp/filewatcher_spec_cube.gcode') }

    before { FileUtils.cp(Rails.root.join('spec/fixture_files/gcode/cura_single.gcode'), path) }
    after { FileUtils.rm_f(path) }

    it 'creates the file and schedules reading its G-code summary' do
      item = nil
      expect { item = described_class.new.send(:create_file_record, path.to_s) }
        .to have_enqueued_job(AnalyseGcodeJob)

      expect(item.reload.gcode_summary).to be_pending
      expect(AnalyseGcodeJob).to have_been_enqueued.with(item.id)
    end
  end
end
