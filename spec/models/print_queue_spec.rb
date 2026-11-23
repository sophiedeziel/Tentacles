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

    it 'pushes nothing without printers' do
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
  end
end
