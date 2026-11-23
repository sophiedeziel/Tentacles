# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Files::UpdateFile, type: :request do
  let(:query) do
    <<~GQL
      mutation($input: UpdateFileInput!) {
        updateFile(input: $input) { file { id filename fileContent gcodeSummary { status } } }
      }
    GQL
  end
  let(:item) { create(:file_record) }

  def update(**input)
    post '/graphql', params: { query:, variables: { input: { id: item.id, **input } } }, as: :json
    response.parsed_body.dig('data', 'updateFile', 'file')
  end

  it 'replaces the content, renames the file, and schedules reading its G-code summary again' do
    create(:gcode_summary, :ready, item:)

    file = nil
    expect { file = update(fileContent: 'G1 X1 E1', fileName: 'cube.gcode') }
      .to have_enqueued_job(AnalyseGcodeJob).with(item.id)
    expect(file).to include('filename' => 'cube.gcode', 'fileContent' => 'G1 X1 E1')
    expect(file['gcodeSummary']).to eq('status' => 'PENDING')
    expect(item.reload.gcode_summary).to be_pending
  end

  context 'when the file is in the print queue' do
    let!(:entry) { create(:print_job, item:, copies: 1) }

    it 'leaves it as it was' do
      content = item.file_content

      expect(update(fileContent: 'G1 X1 E1')).to be_nil
      expect(item.reload.file_content).to eq content
    end

    it 'replaces the content once its entry is finished' do
      create(:printer_job, :copy, print_job: entry, status: 'completed')

      expect(update(fileContent: 'G1 X1 E1')).to include('fileContent' => 'G1 X1 E1')
      expect(item.reload.file_content).to eq 'G1 X1 E1'
    end
  end
end
