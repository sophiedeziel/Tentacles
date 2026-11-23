# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UploadFilesToPrintersJob, type: :job do
  describe '#perform' do
    let(:file) { create(:file_record) }
    let(:path) { Rails.root.join("tmp/#{file.filename}").to_s }

    context 'with the upload stubbed' do
      let(:upload) { instance_double(Printer::Upload, save!: true) }

      before { allow(Printer::Upload).to receive(:new).and_return(upload) }

      def expect_upload(printer, print:)
        expect(Printer::Upload).to have_received(:new).with(printer:, path:, print:)
        expect(upload).to have_received(:save!)
      end

      it 'uploads files to printers' do
        printer = create(:printer)

        UploadFilesToPrintersJob.perform_now([file.id], [printer.id])

        expect_upload(printer, print: false)
      end

      it 'starts printing the files when asked to' do
        printer = create(:printer)

        UploadFilesToPrintersJob.perform_now([file.id], [printer.id], print: true)

        expect_upload(printer, print: true)
      end

      it 'accepts the string IDs of the SendFilesToPrinters mutation' do
        printer = create(:printer)

        UploadFilesToPrintersJob.perform_now([file.id.to_s], [printer.id.to_s])

        expect_upload(printer, print: false)
      end
    end

    # Spooler::Print used to pass `select: true, print: true`, which Printer::Upload doesn't accept
    it 'refuses the keywords Printer::Upload does not accept' do
      printer = create(:printer)

      expect { UploadFilesToPrintersJob.perform_now([file.id], [printer.id], select: true, print: true) }
        .to raise_error(ArgumentError, /select/)
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
    end
  end
end
