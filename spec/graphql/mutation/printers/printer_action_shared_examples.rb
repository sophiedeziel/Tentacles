# frozen_string_literal: true

# Shared examples for the printer action mutations (see Mutations::Printers::PrinterAction).
#
# OctoPrint is stubbed at the gem boundary: Octoprint::Job.get answers with `job_state`, and the commands return true.

# One OctoPrint state text per family
PRINTER_ACTION_STATES = {
  Printer::StateFamily::Printing => 'Printing',
  Printer::StateFamily::Paused => 'Paused',
  Printer::StateFamily::Cancelling => 'Cancelling',
  Printer::StateFamily::Operational => 'Operational',
  Printer::StateFamily::Connecting => 'Detecting baudrate',
  Printer::StateFamily::Error => 'Offline after error',
  Printer::StateFamily::Offline => 'Offline'
}.freeze

RSpec.shared_context 'with a printer action request' do |mutation|
  let(:redis) { MockRedis.new }
  let(:printer) { create(:printer, name: 'Prusa MK4') }
  let(:job_state) { 'Operational' }
  let(:json) { response.parsed_body }
  let(:result) { json['data'][mutation] }
  let(:returned_printer) { { 'id' => printer.id.to_s, 'name' => 'Prusa MK4' } }
  # The status the inline refresh reloads (see Printer::Command#refresh_status)
  let(:refreshed_status) { instance_spy(Printer::Status) }
  let(:query) do
    <<~GQL
      mutation($input: #{mutation.upcase_first}Input!) {
        #{mutation}(input: $input) { success errors printer { id name } }
      }
    GQL
  end

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(Octoprint::Job).to receive(:get) { Octoprint::Job.deserialize({ state: job_state, job: {} }) }
    allow(Printer::Status).to receive(:find_or_initialize_by).and_return(refreshed_status)
  end

  def run_mutation(printer_id = printer.id)
    post '/graphql', params: { query:, variables: { input: { printerId: printer_id.to_s } } }
  end
end

# OctoPrint failures and unknown printers. Expects the including group to be in a state that allows the action.
#
# commands: the [receiver, method] OctoPrint calls of the action, stubbed by the including group
RSpec.shared_examples 'a printer action that fails gracefully' do |commands:|
  def expect_failure(message)
    expect(json['errors']).to be_nil
    expect(result).to eq('success' => false, 'errors' => [message], 'printer' => returned_printer)
    expect(Printer::Status).not_to have_received(:find_or_initialize_by)
  end

  def expect_no_command(commands)
    commands.each { |receiver, method| expect(receiver).not_to have_received(method) }
  end

  context 'when reading the state fails' do
    before do
      allow(Octoprint::Job).to receive(:get)
        .and_raise(Octoprint::Exceptions::ConnectionError, 'Failed to open TCP connection to 10.0.1.165:80')
      run_mutation
    end

    it 'returns the error without sending any command' do
      expect_failure("Could not reach Prusa MK4's OctoPrint: Failed to open TCP connection to 10.0.1.165:80")
      expect_no_command(commands)
    end
  end

  context 'when an error message contains the API key' do
    before do
      allow(Octoprint::Job).to receive(:get)
        .and_raise(Octoprint::Exceptions::ConnectionError, "Failed with key #{printer.secret}")
      run_mutation
    end

    it { expect_failure("Could not reach Prusa MK4's OctoPrint: Failed with key [FILTERED]") }
  end

  context 'when the printer has no OctoPrint API key' do
    let(:printer) { create(:printer, :unvalidated, name: 'Prusa MK4', secret: nil) }

    before { run_mutation }

    it 'returns the error without calling OctoPrint' do
      expect_failure('Prusa MK4 has no OctoPrint URL or API key')
      expect(Octoprint::Job).not_to have_received(:get)
      expect_no_command(commands)
    end
  end

  context 'when the printer has a malformed OctoPrint URL' do
    let(:printer) { create(:printer, name: 'Prusa MK4', uri: 'http://octo pi.local') }

    before do
      allow(Octoprint::Job).to receive(:get).and_call_original
      run_mutation
    end

    it 'returns the error without sending any command' do
      expect_failure('Prusa MK4 has an invalid OctoPrint URL')
      expect_no_command(commands)
    end
  end

  context 'when the printer does not exist' do
    before { run_mutation(0) }

    it 'returns an error and no printer' do
      expect(json['errors']).to be_nil
      expect(result).to eq('success' => false, 'errors' => ['Printer not found'], 'printer' => nil)
      expect(Octoprint::Job).not_to have_received(:get)
    end
  end
end

# The result of an action through GraphQL, when it is allowed, refused or fails. The command itself, for every state
# family, is in spec/models/printer/command_shared_examples.rb.
#
# commands: the [receiver, method] OctoPrint calls the action sends
# allowed:  the families in which the action is allowed
# refusals: the error message for a family in which it is refused
RSpec.shared_examples 'a printer action' do |mutation:, commands:, allowed:, refusals:|
  include_context 'with a printer action request', mutation

  before { commands.each { |receiver, method| allow(receiver).to receive(method).and_return(true) } }

  allowed.each do |family|
    context "when the printer is #{family.serialize}" do
      let(:job_state) { PRINTER_ACTION_STATES.fetch(family) }

      before { run_mutation }

      it 'succeeds and returns the printer' do
        expect(json['errors']).to be_nil
        expect(result).to eq('success' => true, 'errors' => [], 'printer' => returned_printer)
      end
    end
  end

  refusals.each do |family, message|
    context "when the printer is #{family.serialize}" do
      let(:job_state) { PRINTER_ACTION_STATES.fetch(family) }

      before { run_mutation }

      it 'refuses with a readable error, without sending anything' do
        expect(result).to eq('success' => false, 'errors' => [message], 'printer' => returned_printer)
        commands.each { |receiver, method| expect(receiver).not_to have_received(method) }
        expect(Printer::Status).not_to have_received(:find_or_initialize_by)
      end
    end
  end

  context 'when the printer is in an allowed state' do
    let(:job_state) { PRINTER_ACTION_STATES.fetch(allowed.first) }

    it_behaves_like 'a printer action that fails gracefully', commands:
  end
end
