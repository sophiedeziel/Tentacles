# frozen_string_literal: true

# Shared context for the queue operations (see PrintQueue::Operation): the global queue is on, and
# PrintQueue.push_changed and the dispatch requests (`dispatch_request`, a spy returned by PrintQueue::DispatchRequest.new)
# are spied on.
RSpec.shared_context 'with a queue operation' do
  let(:dispatch_request) { instance_spy(PrintQueue::DispatchRequest, save: true) }

  before do
    allow(PrintQueue).to receive(:enabled?).and_return(true)
    allow(PrintQueue).to receive(:push_changed)
    allow(PrintQueue::DispatchRequest).to receive(:new).and_return(dispatch_request)
  end

  # PrintQueue.push_changed was called once, with these printers
  def expect_pushed_once(printers = [])
    expect(PrintQueue).to have_received(:push_changed).once.with(printers)
  end

  def expect_dispatch_requested
    expect(dispatch_request).to have_received(:save).once
  end

  def expect_no_dispatch_requested
    expect(dispatch_request).not_to have_received(:save)
  end

  # The operation was refused with these messages, without a push or a dispatch request
  def expect_refused(operation, *messages)
    expect(operation.save).to be false
    expect(operation.errors.full_messages).to eq messages
    expect(PrintQueue).not_to have_received(:push_changed)
    expect_no_dispatch_requested
  end
end

# The operation (`operation`, unsaved) is refused while the global queue is off. In a group with the context above
RSpec.shared_examples 'a queue operation' do
  it 'is refused while the global queue is off' do
    allow(PrintQueue).to receive(:enabled?).and_return(false)

    expect(operation.save).to be false
    expect(operation.errors[:base]).to include 'The global print queue is off'
    expect(PrintQueue).not_to have_received(:push_changed)
    expect_no_dispatch_requested
  end
end
