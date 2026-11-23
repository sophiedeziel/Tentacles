# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Setting do
  describe '.current' do
    it 'creates the row with the defaults on its first read: dispatch not paused' do
      expect { described_class.current }.to change(described_class, :count).from(0).to(1)
      expect(described_class.current).to have_attributes(id: described_class::ID, dispatch_paused: false)
    end

    it 'reads the same row afterwards' do
      setting = described_class.current
      setting.update!(dispatch_paused: true)

      expect(described_class.current).to eq setting
      expect(described_class.count).to eq 1
    end

    it 'finds the row another process created meanwhile, rather than creating a second one' do
      create(:print_queue_setting, dispatch_paused: true)
      allow(described_class).to receive(:find_by).and_return(nil) # the row wasn't there yet when it looked

      expect(described_class.current).to have_attributes(id: described_class::ID, dispatch_paused: true)
      expect(described_class.count).to eq 1
    end
  end

  describe '.lock_current' do
    it 'reads the row, locked' do
      setting = create(:print_queue_setting, dispatch_paused: true)

      described_class.transaction do
        expect(described_class.lock_current).to eq setting
      end
    end

    it 'locks it FOR UPDATE' do
      create(:print_queue_setting)
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] }

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        described_class.transaction { described_class.lock_current }
      end

      expect(queries).to include(/print_queue_settings.*FOR UPDATE/)
    end

    it 'creates the row with the defaults when there is none' do
      described_class.transaction do
        expect { described_class.lock_current }.to change(described_class, :count).from(0).to(1)
      end
      expect(described_class.current).to have_attributes(id: described_class::ID, dispatch_paused: false)
    end
  end

  describe '.dispatch_paused?' do
    it 'is false until the dispatch is paused' do
      expect(described_class.dispatch_paused?).to be false

      described_class.current.update!(dispatch_paused: true)

      expect(described_class.dispatch_paused?).to be true
    end
  end
end
