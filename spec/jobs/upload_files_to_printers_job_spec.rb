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

    context 'with a PrusaLink printer' do
      let(:printer) { create(:printer, :prusalink, name: 'Prusa MK4') }

      before do
        allow(Prusalink::Storage).to receive(:list).and_return(
          [Prusalink::Storage.deserialize({ name: 'usb', type: 'USB', path: '/usb', available: true,
                                            read_only: false })]
        )
        allow(Prusalink::Files).to receive(:upload).and_return(true)
      end

      it 'uploads the file to the USB drive and starts the print' do
        UploadFilesToPrintersJob.perform_now([file.id], [printer.id], print: true)

        expect(Prusalink::Files).to have_received(:upload)
          .with(path, storage: '/usb', path: 'test.gcode', print_after_upload: true, overwrite: true)
      end

      it 'only uploads the file by default' do
        UploadFilesToPrintersJob.perform_now([file.id], [printer.id])

        expect(Prusalink::Files).to have_received(:upload).with(path, hash_including(print_after_upload: false))
      end

      it 'raises a readable error when the printer has no USB drive' do
        allow(Prusalink::Storage).to receive(:list).and_return([])

        expect { UploadFilesToPrintersJob.perform_now([file.id], [printer.id], print: true) }
          .to raise_error(PrinterBackends::Error, 'Prusa MK4 has no writable storage. Insert a USB drive')
      end
    end
  end
end
