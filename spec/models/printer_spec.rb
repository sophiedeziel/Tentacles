# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Printer, type: :model do
  let(:printer) { build(:printer) }

  it 'has a valid factory' do
    expect(printer).to be_valid
  end

  describe 'octoprint_version', :vcr do

    subject { printer.octoprint_version }

    it           { is_expected.to be_a(Octoprint::ServerVersion) }
    its(:api)    { is_expected.to eq('0.1') }
    its(:server) { is_expected.to eq('1.7.3') }
    its(:text)   { is_expected.to eq('OctoPrint 1.7.3') }
  end

  describe 'job_status', :vcr do
    subject { printer.job_status }

    it { is_expected.to eq 'Operational' }
  end

  describe 'using_api', :vcr do
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
