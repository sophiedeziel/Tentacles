# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Files::ReanalyseGcode, type: :request do
  let(:query) do
    <<~GQL
      mutation($input: ReanalyseGcodeInput!) {
        reanalyseGcode(input: $input) { file { id gcodeSummary { status error } } errors { field message } }
      }
    GQL
  end
  let(:data) { response.parsed_body.dig('data', 'reanalyseGcode') }

  def reanalyse(file_id)
    post '/graphql', params: { query:, variables: { input: { fileId: file_id } } }, as: :json
  end

  it 'resets a failed summary to PENDING and enqueues one AnalyseGcodeJob' do
    summary = create(:gcode_summary, status: 'failed', error: 'Not a G-code text file')

    expect { reanalyse(summary.file_record_id) }.to have_enqueued_job(AnalyseGcodeJob).once
                                                .with(summary.file_record_id)
    expect(data).to eq('file' => { 'id' => summary.file_record_id.to_s,
                                   'gcodeSummary' => { 'status' => 'PENDING', 'error' => nil } },
                       'errors' => [])
  end

  it 'says when the file is not found' do
    expect { reanalyse('0') }.not_to have_enqueued_job(AnalyseGcodeJob)
    expect(data).to eq('file' => nil, 'errors' => [{ 'field' => nil, 'message' => 'File not found' }])
  end

  it 'says when the file is not G-code' do
    item = create(:file_record)
    item.file.attach(io: StringIO.new('solid cube'), filename: 'cube.stl')

    expect { reanalyse(item.id) }.not_to have_enqueued_job(AnalyseGcodeJob)
    expect(data['errors']).to eq [{ 'field' => nil, 'message' => 'Not a G-code file' }]
  end
end
