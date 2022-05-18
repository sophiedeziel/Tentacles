# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UploadFilesToPrintersJob, type: :job do
  describe '#perform' do
    it 'uploads files to printers' do
      printer = create(:printer)
      file = create(:file_manager_file)

      expect_any_instance_of(Printer).to receive(:upload).with("#{Rails.root}/tmp/#{file.filename}")

      UploadFilesToPrintersJob.perform_now([file.id], [printer.id])
    end
  end
end
