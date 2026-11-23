# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::Labeling, type: :model do
  let(:item) { create(:file_record) }
  let(:label) { create(:label) }

  describe 'a label on a file' do
    before { item.labels << label }

    it 'refuses the same label twice on the same file' do
      duplicate = Library::Labeling.new(item:, label:)

      expect(duplicate).to_not be_valid
      expect(duplicate.errors.of_kind?(:file_record_id, :taken)).to eq true
    end

    it 'raises when the label is added to the file again' do
      expect { item.labels << label }.to raise_error(ActiveRecord::RecordInvalid, /File record has already been taken/)
      expect(Library::Labeling.where(item:, label:).count).to eq 1
    end

    it 'allows the same label on another file' do
      expect(Library::Labeling.new(item: create(:file_record), label:)).to be_valid
    end

    it 'allows another label on the same file' do
      expect(Library::Labeling.new(item:, label: create(:label, name: 'My blue label'))).to be_valid
    end
  end
end
