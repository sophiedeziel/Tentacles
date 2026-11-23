# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Files::UpdateFile, type: :request do
  let(:query) do
    <<~GQL
      mutation($input: UpdateFileInput!) {
        updateFile(input: $input) { file { id filename fileContent } }
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
    expect(item.reload.gcode_summary).to be_pending
  end
end
