# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue do
  describe '.enabled?' do
    around do |example|
      flag = Rails.configuration.x.global_print_queue
      example.run
    ensure
      Rails.configuration.x.global_print_queue = flag
    end

    it 'is off in the test environment (GLOBAL_PRINT_QUEUE unset)' do
      expect(described_class.enabled?).to be false
    end

    it 'follows config.x.global_print_queue' do
      Rails.configuration.x.global_print_queue = true

      expect(described_class.enabled?).to be true
    end
  end

  describe '.push_changed' do
    let(:subscriptions) { TentaclesSchema.subscriptions }
    let(:printers) { create_list(:printer, 2) }
    # The printQueueChanged triggers, as [printer id, ...]
    let(:pushes) { [] }

    before do
      allow(subscriptions).to receive(:trigger) do |name, arguments, object|
        pushes << object.id if name == :print_queue_changed && arguments == {}
      end
    end

    it 'pushes printQueueChanged once for each printer' do
      described_class.push_changed([printers.first, printers.last, printers.first])

      expect(pushes).to eq printers.map(&:id)
    end

    it 'pushes no printer without printers' do
      described_class.push_changed

      expect(pushes).to be_empty
    end

    it 'logs a push that fails, without raising, and still pushes the next printers' do
      allow(subscriptions).to receive(:trigger).with(:print_queue_changed, {}, printers.first)
                                               .and_raise(Redis::CannotConnectError)
      allow(Rails.logger).to receive(:error)

      expect { described_class.push_changed(printers) }.not_to raise_error
      expect(Rails.logger).to have_received(:error)
        .with(/Could not push printQueueChanged for printer #{printers.first.id}/)
      expect(pushes).to eq [printers.last.id]
    end

    describe 'queueChanged' do
      # The queueChanged triggers
      let(:queue_pushes) { [] }

      before do
        allow(described_class).to receive(:enabled?).and_return(true)
        allow(subscriptions).to receive(:trigger) do |name, arguments, object|
          pushes << object.id if name == :print_queue_changed && arguments == {}
          queue_pushes << [arguments, object] if name == :queue_changed
        end
      end

      it 'pushes queueChanged once, after the printers' do
        names = []
        allow(subscriptions).to receive(:trigger) { |name, *| names << name }

        described_class.push_changed(printers)

        expect(names).to eq %i[print_queue_changed print_queue_changed queue_changed]
      end

      it 'pushes queueChanged alone without printers' do
        described_class.push_changed

        expect(pushes).to be_empty
        expect(queue_pushes).to eq [[{}, {}]]
      end

      it 'pushes no queueChanged while the global queue is off' do
        allow(described_class).to receive(:enabled?).and_return(false)

        described_class.push_changed(printers)

        expect(pushes).to eq printers.map(&:id)
        expect(queue_pushes).to be_empty
      end

      it 'logs a queueChanged push that fails, without raising, after pushing the printers' do
        allow(subscriptions).to receive(:trigger).with(:queue_changed, {}, {}).and_raise(Redis::CannotConnectError)
        allow(Rails.logger).to receive(:error)

        expect { described_class.push_changed(printers) }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Could not push queueChanged: Redis::CannotConnectError/)
        expect(pushes).to eq printers.map(&:id)
      end

      it 'still pushes queueChanged when a printer push fails' do
        allow(subscriptions).to receive(:trigger).with(:print_queue_changed, {}, printers.first)
                                                 .and_raise(Redis::CannotConnectError)
        allow(Rails.logger).to receive(:error)

        described_class.push_changed(printers)

        expect(queue_pushes).to eq [[{}, {}]]
      end
    end
  end
end
