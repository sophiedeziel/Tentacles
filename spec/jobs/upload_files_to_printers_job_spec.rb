# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UploadFilesToPrintersJob, type: :job do
  describe '#perform' do
    it 'uploads files to printers' do
      printer = create(:printer)
      file = create(:file_record)

      expect_any_instance_of(Printer).to receive(:upload).with(Rails.root.join("tmp/#{file.filename}").to_s)

      UploadFilesToPrintersJob.perform_now([file.id], [printer.id])
    end
  end
end
