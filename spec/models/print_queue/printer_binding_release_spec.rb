# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::PrinterBindingRelease do
  include_context 'with a queue operation'

  let(:printer) { create(:printer) }
  let(:job) { create(:print_job, copies: 3, same_printer: true, bound_printer: printer) }

  def release(on: job)
    described_class.new(job: on).tap(&:save)
  end

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(job:) }
  end

  it 'lets the copies go to any printer' do
    expect(release.errors).to be_empty
    expect(job.reload).to have_attributes(same_printer: false, bound_printer: nil)
  end

  it 'pushes the printer it was bound to, once, and asks for a dispatch pass' do
    release

    expect_pushed_once([printer])
    expect_dispatch_requested
  end

  it 'pushes no printer for an entry not bound yet' do
    job.update!(bound_printer: nil)

    release

    expect(job.reload.same_printer).to be false
    expect_pushed_once([])
    expect_dispatch_requested
  end

  it 'is refused for a finished entry' do
    3.times { create(:printer_job, :copy, print_job: job, status: 'completed', printer:) }

    expect_refused(described_class.new(job:), 'test.gcode is no longer in the queue')
    expect(job.reload.bound_printer).to eq printer
  end
end
