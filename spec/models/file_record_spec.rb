# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FileRecord, type: :model do
  let(:file) { create(:file_record) }

  it 'has a valid factory' do
    expect(file).to be_valid
    expect(build(:file_record, :with_labels)).to be_valid
  end

  describe '#filename' do
    subject { file.filename }

    it { is_expected.to eq 'test.gcode' }
  end

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

  describe '#is_not_archived?' do
    subject { file.is_not_archived? }

    it { is_expected.to eq true }

    context 'when the file is archived' do
      before { file.archive }
      it { is_expected.to eq false }
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

  describe '#deleted?' do
    subject { file.deleted? }

    it { is_expected.to eq false }
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

  describe '#file_content' do
    subject { file.file_content }

    it { is_expected.to eq Rails.root.join('spec/fixture_files/test.gcode').read }
  end

  describe '#change_file_content!' do
    subject { file.change_file_content!(content) }

    let(:content) { 'new_content' }

    it 'changes the file content' do
      expect { subject }.to change {
                              file.file_content
                            }.from(Rails.root.join('spec/fixture_files/test.gcode').read).to(content)
    end
  end

  describe '#labels' do
    subject { build(:file_record, :with_labels).labels }

    it { is_expected.to_not be_nil }
    it { is_expected.to_not be_empty }

    it 'does not have duplicate labels associated to a single file record' do
      file_record = create(:file_record, :with_labels)
      file_record.labels.build(file_records: [file_record])

      expect(file_record).to be_invalid # (same as to_not be_valid)
    end
  end
end
