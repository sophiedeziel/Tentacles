# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Files::UploadFile, type: :request do
  let(:query) do
    <<~GQL
      mutation($input: UploadFileInput!) {
        uploadFile(input: $input) { file { id filename } }
      }
    GQL
  end

  def upload(fixture, filename)
    upload = Rack::Test::UploadedFile.new(Rails.root.join(fixture), 'application/octet-stream',
                                          original_filename: filename)
    operations = { query:, variables: { input: { fileAttributes: { notes: '', file: nil } } } }
    map = { '0' => ['variables.input.fileAttributes.file'] }
    post '/graphql', params: { operations: operations.to_json, map: map.to_json, '0' => upload }
    response.parsed_body.dig('data', 'uploadFile', 'file')
  end

  it 'schedules reading the G-code summary of an uploaded G-code file' do
    file = nil
    expect { file = upload('spec/fixture_files/gcode/cura_single.gcode', 'cube.gcode') }
      .to have_enqueued_job(AnalyseGcodeJob)

    item = Library::Item.find(file['id'])
    expect(item.gcode_summary).to be_pending
    expect(AnalyseGcodeJob).to have_been_enqueued.with(item.id)
  end
end
