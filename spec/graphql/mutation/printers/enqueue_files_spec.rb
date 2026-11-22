# frozen_string_literal: true

require 'rails_helper'

# Enqueue-time auto-start, pinned as it is (startNextPrint's guard doesn't apply to it): the start_print command is
# published when the queue held exactly one job BEFORE the new ones were enqueued (`printer.queue.size == 1` is read
# before the job is created).
RSpec.describe Mutations::Printers::EnqueueFiles, type: :request do
  # MockRedis doesn't implement PUBLISH
  let(:redis) { MockRedis.new.tap { |redis| redis.define_singleton_method(:publish) { |_channel, _message| 0 } } }
  let(:printer) { create(:printer) }
  let(:file) { create(:file_record) }
  let(:start_print_message) { { command: :start_print, printer_id: printer.id }.to_json }
  let(:query) do
    <<~GQL
      mutation($input: EnqueueFilesInput!) { enqueueFiles(input: $input) { jobs { id } } }
    GQL
  end

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(redis).to receive(:publish)
    allow(Octoprint::Job).to receive(:get)
  end

  def enqueue
    post '/graphql',
         params: { query:, variables: { input: { fileIds: [file.id.to_s], printerIds: [printer.id.to_s] } } }
  end

  it 'publishes start_print when the queue held one job, without checking the printer state' do
    create(:printer_job, printer:, status: 'enqueued')

    enqueue

    expect(printer.queue.count).to eq 2
    expect(redis).to have_received(:publish).with('printers', start_print_message).once
    expect(Octoprint::Job).not_to have_received(:get)
  end

  it 'does not publish when the queue was empty' do
    enqueue

    expect(printer.queue.count).to eq 1
    expect(redis).not_to have_received(:publish)
  end

  it 'does not publish when the queue held more than one job' do
    create_list(:printer_job, 2, printer:, status: 'enqueued')

    enqueue

    expect(printer.queue.count).to eq 3
    expect(redis).not_to have_received(:publish)
  end

  describe 'printQueueChanged' do
    let(:other_printer) { create(:printer) }
    # The printQueueChanged triggers, as [printer id, ...]
    let(:pushes) { [] }

    before do
      allow(TentaclesSchema.subscriptions).to receive(:trigger) do |name, _arguments, object|
        pushes << object.id if name == :print_queue_changed
      end
    end

    def enqueue_ids(file_ids, printer_ids)
      post '/graphql', params: { query:, variables: { input: { fileIds: file_ids, printerIds: printer_ids } } }
    end

    it 'is pushed once per printer, once all the files are enqueued' do
      enqueue_ids([file.id.to_s, create(:file_record).id.to_s], [printer.id.to_s, other_printer.id.to_s])

      expect([printer.queue.count, other_printer.queue.count]).to eq [2, 2]
      expect(pushes).to contain_exactly(printer.id, other_printer.id)
    end

    it 'is pushed for the jobs enqueued before a file that is not found' do
      enqueue_ids([file.id.to_s, '0'], [printer.id.to_s])

      expect(response).to have_http_status(:not_found)
      expect(printer.queue.count).to eq 1
      expect(pushes).to eq [printer.id]
    end
  end
end
