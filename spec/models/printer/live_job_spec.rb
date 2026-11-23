# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::LiveJob do
  let(:printer) { build(:printer) }

  describe '.find_by' do
    it "reads the printer's live job through its adapter" do
      allow(printer.api).to receive(:live_job)
        .and_return(state_family: Printer::StateFamily::Paused, file_name: 'cube.bgcode', job_id: 7)

      expect(described_class.find_by(printer:)).to have_attributes(printer:, state_family: Printer::StateFamily::Paused,
                                                                   file_name: 'cube.bgcode', job_id: 7)
    end

    it 'has no file nor job id when no job is loaded (or the backend has no job ids)' do
      allow(printer.api).to receive(:live_job).and_return(state_family: Printer::StateFamily::Operational,
                                                          file_name: nil)

      expect(described_class.find_by(printer:)).to have_attributes(file_name: nil, job_id: nil)
    end

    it "raises the adapter's errors" do
      allow(printer.api).to receive(:live_job).and_raise(Printer::Backend::Unreachable, 'timeout')

      expect { described_class.find_by(printer:) }.to raise_error(Printer::Backend::Unreachable, 'timeout')
    end
  end

  it 'is read-only' do
    live_job = described_class.new(printer:, state_family: Printer::StateFamily::Printing)

    expect(live_job).to be_readonly
    expect { live_job.save }.to raise_error(ApplicationModel::ReadOnlyRecord)
  end
end
