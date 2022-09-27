# frozen_string_literal: true

require 'rails_helper'
require 'spooler'

RSpec.describe Spooler do
  let(:spooler) { Spooler.new }

  describe '#run' do
    subject { spooler.run }

    it 'runs the spooler in a loop' do
      allow(spooler).to receive(:subcribe_to_commands)
      expect(spooler).to receive(:loop).and_yield
      subject
    end
  end

  describe '#log' do
    it 'formats the message' do
      expect { spooler.log 'test' }.to output("         [ Spooler ] : test\n").to_stdout
    end
  end
end
