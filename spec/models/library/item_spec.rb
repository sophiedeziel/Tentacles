# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::Item, type: :model do
  let(:file) { create(:file_record) }

  describe '#filetype' do
    subject { file.filetype }

    it { is_expected.to eq '.gcode' }
  end

  describe '#filesize' do
    subject { file.filesize }

    it { is_expected.to eq 949_599 }
  end

  describe '#archive' do
    subject { file.archive }

    it 'archives the file' do
      expect { subject }.to change { file.is_not_archived }.from(true).to(false)
    end
  end

  describe '#archived?' do
    subject { file.archived? }

    it { is_expected.to eq false }

    context 'when the file is archived' do
      before { file.archive }
      it { is_expected.to eq true }
    end
  end

  describe '#unarchive' do
    subject { file.unarchive }

    it 'unarchives the file' do
      file.archive
      expect { subject }.to change { file.is_not_archived }.from(false).to(true)
    end
  end

  describe '#download_url' do
    subject { file.download_url }

    it { is_expected.to match(%r{/rails/active_storage.+/test.gcode}) }
  end

  describe '#top_file_comments' do
    subject { file.top_file_comments }

    it 'returns the comment lines from the top of the file' do
      expect(subject).to eq [
        ';FLAVOR:Marlin',
        ';TIME:4271',
        ';Filament used: 0.797727m',
        ';Layer height: 0.12',
        ';MINX:119.5',
        ';MINY:39.5',
        ';MINZ:0.12',
        ';MAXX:180.5',
        ';MAXY:260.5',
        ';MAXZ:0.36',
        ';Generated with Cura_SteamEngine 4.11.0'
      ].join("\r\n")
    end

    context 'when the file is only comments' do
      let(:file) { create(:file_record, :only_comments) }

      it 'returns the comment lines from the top of the file' do
        expect(subject).to eq [
          ';FLAVOR:Marlin',
          ';TIME:4271',
          ';Filament used: 0.797727m',
          ';Layer height: 0.12',
          ';MINX:119.5',
          ';MINY:39.5',
          ';MINZ:0.12',
          ';MAXX:180.5',
          ';MAXY:260.5',
          ';MAXZ:0.36',
          '',
          ';Generated with Cura_SteamEngine 4.11.0'
        ].join("\r\n")
      end
    end
  end

  describe 'destroy' do
    it 'deletes the jobs that print the file' do
      job = create(:printer_job, executable: file)

      file.destroy!

      expect(Printer::Job.exists?(job.id)).to be false
      expect(Printer.exists?(job.printer_id)).to be true
    end
  end

  describe '#gcode?' do
    it 'is true for a .gcode file, whatever its case' do
      expect(file).to be_gcode
      file.file.attach(io: StringIO.new('G1'), filename: 'CUBE.GCODE')
      expect(file).to be_gcode
    end

    it 'is false for another file, binary G-code included' do
      file.file.attach(io: StringIO.new('GCDE'), filename: 'cube.bgcode')
      expect(file).not_to be_gcode
    end
  end
end
