# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UploadFilesToPrintersJob, type: :job do
  describe '#perform' do
    let(:file) { create(:file_record) }
    let(:path) { Rails.root.join("tmp/#{file.filename}").to_s }

    it 'uploads files to printers' do
      printer = create(:printer)

      expect_any_instance_of(Printer).to receive(:upload).with(path, print: false)

      UploadFilesToPrintersJob.perform_now([file.id], [printer.id])
    end

    it 'starts printing the files when asked to' do
      printer = create(:printer)

      expect_any_instance_of(Printer).to receive(:upload).with(path, print: true)

      UploadFilesToPrintersJob.perform_now([file.id], [printer.id], print: true)
    end

    it 'accepts the string IDs of the SendFilesToPrinters mutation' do
      printer = create(:printer)

      expect_any_instance_of(Printer).to receive(:upload).with(path, print: false)

      UploadFilesToPrintersJob.perform_now([file.id.to_s], [printer.id.to_s])
    end

    # Spooler::Print used to pass `select: true, print: true`, which Printer#upload doesn't accept
    it 'refuses the keywords Printer#upload does not accept' do
      printer = create(:printer)

      expect { UploadFilesToPrintersJob.perform_now([file.id], [printer.id], select: true, print: true) }
        .to raise_error(ArgumentError, /select/)
    end

    it 'starts the print through the OctoPrint adapter' do
      printer = create(:printer)
      allow(Octoprint::Files).to receive(:upload).and_return(Octoprint::Files::OperationResult.new(done: true))

      UploadFilesToPrintersJob.perform_now([file.id], [printer.id], print: true)

      expect(Octoprint::Files).to have_received(:upload)
        .with(path, options: { path: nil, select: true, print: true, userdata: nil })
    end
  end
end
