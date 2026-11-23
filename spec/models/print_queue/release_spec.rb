# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::Release do
  include_context 'with a queue operation'

  let(:job) { create(:print_job, held: true) }

  def release(entry = job)
    described_class.new(job: entry).tap(&:save)
  end

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(job:) }
  end

  it 'releases the entry' do
    expect(release.errors).to be_empty
    expect(job.reload).not_to be_held
  end

  it 'changes nothing on an entry that is not held' do
    job.update!(held: false)

    expect(release.errors).to be_empty
    expect(job.reload).not_to be_held
  end

  it 'pushes once and asks for a dispatch pass' do
    release

    expect_pushed_once([])
    expect_dispatch_requested
  end

  it 'pushes the printer the entry is bound to' do
    printer = create(:printer)
    job.update!(same_printer: true, bound_printer: printer)

    release

    expect_pushed_once([printer])
  end

  it 'is refused for a finished entry' do
    create(:printer_job, :copy, print_job: job, status: 'completed')

    expect_refused(described_class.new(job:), 'test.gcode is no longer in the queue')
    expect(job.reload).to be_held
  end
end
