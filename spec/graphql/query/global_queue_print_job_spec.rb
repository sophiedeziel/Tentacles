# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query globalQueue.printJob', type: :request do
  let(:query) do
    <<~GRAPHQL
      query($id: ID!) {
        globalQueue {
          printJob(id: $id) { id copies material colour allCapable samePrinter held printers { id name } }
        }
      }
    GRAPHQL
  end

  before { allow(PrintQueue).to receive(:enabled?).and_return(true) }

  def print_job(id)
    post '/graphql', params: { query:, variables: { id: }.to_json }
    body = response.parsed_body
    expect(body['errors']).to be_nil
    body.dig('data', 'globalQueue', 'printJob')
  end

  it 'reads a print job and the printers it is limited to, by name' do
    voron = create(:printer, name: 'Voron 2.4')
    mk4 = create(:printer, name: 'Prusa MK4')
    job = create(:print_job, copies: 3, material: 'PETG', colour: 'Grey', all_capable: false, same_printer: true,
                             printers: [voron, mk4])

    expect(print_job(job.id)).to eq(
      'id' => job.id.to_s, 'copies' => 3, 'material' => 'PETG', 'colour' => 'Grey', 'allCapable' => false,
      'samePrinter' => true, 'held' => false,
      'printers' => [{ 'id' => mk4.id.to_s, 'name' => 'Prusa MK4' }, { 'id' => voron.id.to_s, 'name' => 'Voron 2.4' }]
    )
  end

  it 'has no printers when every printer that can print it may' do
    job = create(:print_job)

    expect(print_job(job.id)).to include('allCapable' => true, 'printers' => [])
  end

  it 'is null when there is no print job with that id' do
    expect(print_job(0)).to be_nil
  end
end
