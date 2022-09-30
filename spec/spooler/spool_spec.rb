# frozen_string_literal: true

require 'rails_helper'
require 'spooler/spool'

RSpec.describe Spooler::Spool do
  let(:printer) { create(:printer) }
  let(:spool) { described_class.new(printer) }

  describe '#working?' do
    subject { spool.working? }

    it { is_expected.to eq false }
  end
end
