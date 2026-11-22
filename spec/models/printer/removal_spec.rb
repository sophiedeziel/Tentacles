# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer::Removal do
  let(:redis) { MockRedis.new.tap { |redis| redis.define_singleton_method(:publish) { |_channel, _message| 0 } } }
  let(:subscriptions) { TentaclesSchema.subscriptions }
  let(:printer) { create(:printer, name: 'Ender 3') }
  let(:other_printer) { create(:printer) }

  before do
    stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis })
    allow(redis).to receive(:publish).and_call_original
    allow(subscriptions).to receive(:trigger)
    [printer, other_printer].each do |each_printer|
      redis.set(Printer::Status.key(each_printer.id), Printer::Status.unknown(printer_id: each_printer.id).to_json)
      Printer::Disconnection.create!(printer_id: each_printer.id)
    end
    redis.set("printer_api_#{printer.id}_version", 'cached')
  end

  def remove
    described_class.new(printer:).save!
  end

  it 'destroys the printer and its jobs' do
    create(:printer_job, printer:, status: 'active')

    remove

    expect(Printer.exists?(printer.id)).to be false
    expect(Printer::Job.where(printer_id: printer.id)).to be_empty
  end

  it "deletes the printer's monitor snapshot and API cache, not those of other printers" do
    remove

    expect(redis.keys).to contain_exactly(Printer::Status.key(other_printer.id),
                                          "printer_#{other_printer.id}_disconnected")
  end

  it 'tells the spooler to drop the printer' do
    remove

    expect(redis).to have_received(:publish)
      .with('printers', { command: 'remove_printer', printer_id: printer.id }.to_json).once
  end

  it 'pushes printQueueChanged and dashboardChanged once each, even with several jobs' do
    create_list(:printer_job, 3, printer:)
    triggers = []
    allow(subscriptions).to receive(:trigger) { |*args| triggers << args } # leaves out the pushes of the creates

    remove

    expect(triggers).to contain_exactly(
      [:print_queue_changed, {}, { removed_printer: hash_including('id' => printer.id, 'name' => 'Ender 3') }],
      [:dashboard_changed, {}, {}]
    )
  end

  it 'never contacts the printer' do
    allow(Printer::Backend).to receive(:for)

    remove

    expect(Printer::Backend).not_to have_received(:for)
  end

  context 'when the printer cannot be destroyed' do
    before { allow(printer).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed) }

    it 'raises a Conflict without cleaning up or pushing anything' do
      expect { remove }.to raise_error(described_class::Conflict) do |error|
        expect(error.cause).to be_a(ActiveRecord::RecordNotDestroyed)
      end

      expect(Printer::Status.find_by(printer_id: printer.id)).to be_present
      expect(redis).not_to have_received(:publish)
      expect(subscriptions).not_to have_received(:trigger)
    end

    it 'returns false from #save, with the error to show' do
      removal = described_class.new(printer:)

      expect(removal.save).to be(false)
      expect(removal.errors.full_messages).to eq(['The printer changed while removing it, try again'])
    end
  end

  it 'is invalid without a printer' do
    removal = described_class.new

    expect(removal.save).to be(false)
    expect(removal.errors.full_messages).to eq(["Printer can't be blank"])
  end

  it 'runs the cleanup steps in order' do
    steps = []
    allow(Printer::Status).to receive(:delete_by) { steps << :forget }
    allow(redis).to receive(:publish) { steps << :spool }
    allow(subscriptions).to receive(:trigger) { |event, *_args| steps << event }

    remove

    expect(steps).to eq(%i[forget spool print_queue_changed dashboard_changed])
  end

  context 'when Redis fails after the printer is destroyed' do
    before do
      allow(Printer::Status).to receive(:delete_by).and_raise(Redis::CannotConnectError)
      allow(redis).to receive(:publish).and_raise(Redis::CannotConnectError)
      allow(Rails.logger).to receive(:error)
    end

    it 'logs each failure and still runs the next steps' do
      remove

      expect(Printer.exists?(printer.id)).to be false
      expect(Rails.logger).to have_received(:error).with(/could not forget its Redis keys/)
      expect(Rails.logger).to have_received(:error).with(/could not stop its spool/)
      expect(subscriptions).to have_received(:trigger).twice
    end
  end
end
