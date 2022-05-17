# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FileManager::File, type: :model do
  let(:file) { create(:file_manager_file) }

  it 'has a valid factory' do
    expect(file).to be_valid
  end
end
