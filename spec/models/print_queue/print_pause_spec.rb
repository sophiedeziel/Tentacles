# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::PrintPause do
  include_context 'with a queue operation'

  let(:printer) { create(:printer) }
  let(:printer_job) { create(:printer_job, :copy, printer:, status: 'active') }

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(printer_job:) }
  end

  it "pushes the copy's printer once, storing nothing" do
    expect(described_class.new(printer_job:).save).to be true

    expect_pushed_once([printer])
    expect_no_dispatch_requested
    expect(printer_job.reload).to have_attributes(status: 'active', finished_at: nil)
  end

  it "is refused for a job of the printer's own queue" do
    own_job = create(:printer_job, printer:, name: 'cube.gcode', status: 'active')

    expect_refused(described_class.new(printer_job: own_job), "cube.gcode isn't a copy of a queue entry")
  end

  it 'is refused without a job' do
    expect_refused(described_class.new(printer_job: nil), "Printer job can't be blank")
  end
end
