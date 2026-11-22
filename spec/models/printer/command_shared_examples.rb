# frozen_string_literal: true

# Shared examples for the printer commands (see Printer::Command). The adapter is stubbed: `printer.api.live_job`
# answers with `live_job`, and the command returns nil. The inline status refresh (Printer::Command#refresh_status)
# gets `refreshed_status`, a spy, from Printer::Status.find_or_initialize_by.

RSpec.shared_context 'with a printer command' do
  let(:printer) { create(:printer, name: 'Prusa MK4') }
  let(:live_job) { { state_family: Printer::StateFamily::Printing, file_name: 'cube.gcode', job_id: nil } }
  let(:refreshed_status) { instance_spy(Printer::Status) }

  before do
    allow(printer.api).to receive(:live_job) { live_job }
    allow(Printer::Status).to receive(:find_or_initialize_by).and_return(refreshed_status)
  end
end

# The command for every state family.
#
# sends:    the adapter method the command calls
# allowed:  the families in which the command is allowed
# refusals: the error message for each other family
RSpec.shared_examples 'a printer command' do |sends:, allowed:, refusals:|
  include_context 'with a printer command'

  subject(:command) { described_class.new(printer:) }

  before { allow(printer.api).to receive(sends) }

  it 'covers every state family' do
    expect(allowed + refusals.keys).to match_array(Printer::StateFamily.values)
  end

  allowed.each do |family|
    context "when the printer is #{family.serialize}" do
      let(:live_job) { super().merge(state_family: family) }

      it 'sends the command, then refreshes the printer status once' do
        expect(command.save).to be true
        expect(command.errors).to be_empty
        expect(printer.api).to have_received(sends).once
        expect(Printer::Status).to have_received(:find_or_initialize_by).once.with(printer:)
        expect(refreshed_status).to have_received(:reload).once
      end
    end
  end

  refusals.each do |family, message|
    context "when the printer is #{family.serialize}" do
      let(:live_job) { super().merge(state_family: family) }

      it 'refuses with a readable error in errors[:base], without sending anything' do
        expect(command.save).to be false
        expect(command.errors.full_messages).to eq([message])
        expect(printer.api).not_to have_received(sends)
        expect(Printer::Status).not_to have_received(:find_or_initialize_by)
      end

      it 'raises ActiveModel::ValidationError with save!' do
        expect { command.save! }.to raise_error(ActiveModel::ValidationError, /#{Regexp.escape(message)}/)
      end
    end
  end

  it 'reads the live job once' do
    command.save
    command.valid?

    expect(printer.api).to have_received(:live_job).once
  end

  it 'needs a printer' do
    command = described_class.new

    expect(command.save).to be false
    expect(command.errors.full_messages).to eq(["Printer can't be blank"])
  end

  context 'when the command fails' do
    let(:live_job) { super().merge(state_family: allowed.first) }

    before do
      allow(printer.api).to receive(sends).and_raise(Printer::Backend::Error, '[409] Printer is not operational')
    end

    it 'returns the readable error, without refreshing the printer status' do
      expect(command.save).to be false
      expect(command.errors.full_messages).to eq(["Prusa MK4's OctoPrint returned an error: [409] Printer is not " \
                                                  'operational'])
      expect(Printer::Status).not_to have_received(:find_or_initialize_by)
    end

    it 'raises it with save!' do
      expect { command.save! }.to raise_error(Printer::Backend::Error)
    end
  end
end

# The commands that act on the job under way (pause, resume, cancel).
#
# sends: the adapter method the command calls, with `job_id:`
# state: a family in which the command is allowed
RSpec.shared_examples 'a job command' do |sends:, state:|
  include_context 'with a printer command'

  let(:live_job) { { state_family: state, file_name: 'bracket_v3.gcode', job_id: 42 } }

  before { allow(printer.api).to receive(sends) }

  def save_expecting(file_name)
    command = described_class.new(printer:, expected_file_name: file_name)
    [command.save, command.errors.full_messages]
  end

  it 'sends the command to the job it checked' do
    described_class.new(printer:).save!

    expect(printer.api).to have_received(sends).once.with(job_id: 42)
  end

  it 'sends job_id: nil for the backends without job ids' do
    live_job[:job_id] = nil
    described_class.new(printer:).save!

    expect(printer.api).to have_received(sends).once.with(job_id: nil)
  end

  it 'acts when the printer is printing the confirmed file' do
    expect(save_expecting('bracket_v3.gcode')).to eq([true, []])
  end

  it 'refuses when the printer is printing another file' do
    live_job[:file_name] = 'gear_v2.gcode'

    expect(save_expecting('bracket_v3.gcode')).to eq([false, ['Prusa MK4 is now printing gear_v2.gcode']])
    expect(printer.api).not_to have_received(sends)
  end

  it 'refuses when the printer reports no file' do
    live_job[:file_name] = nil

    expect(save_expecting('bracket_v3.gcode')).to eq([false, ['Prusa MK4 is no longer printing bracket_v3.gcode']])
    expect(printer.api).not_to have_received(sends)
  end

  it 'only refuses for the state when the state does not allow it either' do
    live_job.merge!(state_family: Printer::StateFamily::Operational, file_name: nil)

    _saved, messages = save_expecting('bracket_v3.gcode')
    expect(messages.size).to eq(1)
    expect(messages.first).not_to include('bracket_v3.gcode')
  end

  it 'does not check the file when none is given' do
    live_job[:file_name] = 'gear_v2.gcode'

    expect(save_expecting(nil)).to eq([true, []])
  end
end

# The commands that connect the printer's server to the printer
RSpec.shared_examples 'a connection command' do |sends:|
  let(:printer) { create(:printer, :prusalink, name: 'Prusa MK4') }

  before do
    allow(printer.api).to receive(:live_job)
    allow(printer.api).to receive(sends)
  end

  it 'is refused for the backends that connect on their own, without reading the state' do
    command = described_class.new(printer:)

    expect(command.save).to be false
    expect(command.errors.full_messages).to eq(['PrusaLink printers connect on their own'])
    expect(printer.api).not_to have_received(:live_job)
    expect(printer.api).not_to have_received(sends)
  end
end
