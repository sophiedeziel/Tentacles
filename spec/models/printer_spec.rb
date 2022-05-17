# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer, type: :model do
  it 'has a valid factory' do
    expect(build(:printer)).to be_valid
  end

  describe 'using_api', :vcr do
    let(:printer) { build(:printer) }
    subject do
      printer.using_api do
        Octoprint::ServerVersion.get
      end
    end

    context 'when octoprint is connected' do
      it 'returns the octoprint version' do
        expect(subject).to be_a(Octoprint::ServerVersion)
      end
    end

    context 'when octoprint is not available' do
      let(:printer) { build(:printer, :disconnected) }

      it 'raises an error' do
        expect { subject }.to raise_error(Octoprint::Exceptions::MissingCredentials)
      end
    end

    context 'when octoprint is misconfigured' do
      let(:printer) { build(:printer, :wrong_credentials) }

      it 'raises an error' do
        expect { subject }.to raise_error(Octoprint::Exceptions::AuthenticationError)
      end
    end
  end
end
