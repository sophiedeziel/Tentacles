# frozen_string_literal: true

# Shared context for the global queue's mutations (Mutations::Queue, setPrinterTakesJobs): the queue is on, the pushes
# (TentaclesSchema.subscriptions.trigger) are spied on, and so are the dispatch requests (`dispatch_request`).
#
#   mutate('holdPrintJob', { id: job.id }, 'printJob { id held }')
#   data # => the mutation's payload
RSpec.shared_context 'with a queue mutation' do
  let(:dispatch_request) { instance_spy(PrintQueue::DispatchRequest, save: true) }
  let(:json) { response.parsed_body }

  before do
    allow(PrintQueue).to receive(:enabled?).and_return(true)
    allow(TentaclesSchema.subscriptions).to receive(:trigger)
    allow(PrintQueue::DispatchRequest).to receive(:new).and_return(dispatch_request)
  end

  # Runs the mutation with this input, selecting `success errors { field message }` and `selection`
  def mutate(mutation, input, selection = '')
    query = <<~GQL
      mutation($input: #{mutation.upcase_first}Input!) {
        #{mutation}(input: $input) { success errors { field message } #{selection} }
      }
    GQL
    post '/graphql', params: { query:, variables: { input: } }, as: :json
    expect(json['errors']).to be_nil
    @mutation = mutation
  end

  def data = json.dig('data', @mutation)

  # The payload's errors, as [field, message] pairs
  def errors = data['errors'].map { |error| error.values_at('field', 'message') }

  def expect_refused(*messages, field: nil)
    expect(data['success']).to be false
    expect(errors).to eq(messages.map { |message| [field, message] })
  end

  def expect_saved
    expect(data['errors']).to eq []
    expect(data['success']).to be true
  end

  def expect_nothing_pushed
    expect(TentaclesSchema.subscriptions).not_to have_received(:trigger)
    expect(dispatch_request).not_to have_received(:save)
  end

  def turn_queue_off
    allow(PrintQueue).to receive(:enabled?).and_return(false)
  end
end
