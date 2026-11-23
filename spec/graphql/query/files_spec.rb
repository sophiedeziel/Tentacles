# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query files', type: :request do
  let(:json) { response.parsed_body }
  let!(:gcode) { create(:file_record) }
  let!(:upper_case) do
    create(:file_record).tap { |item| item.file.attach(io: StringIO.new('G28'), filename: 'BENCHY.GCODE') }
  end
  let!(:stl) { create(:file_record).tap { |item| item.file.attach(io: StringIO.new('solid'), filename: 'cube.stl') } }

  def filenames(query)
    post '/graphql', params: { query: }
    expect(json['errors']).to be_nil
    json.dig('data', 'files').pluck('filename')
  end

  it 'lists every file' do
    expect(filenames('{ files { filename } }')).to contain_exactly('test.gcode', 'BENCHY.GCODE', 'cube.stl')
  end

  it 'lists only the G-code files with gcode: true, whatever the case of their extension' do
    expect(filenames('{ files(gcode: true) { filename } }')).to contain_exactly('test.gcode', 'BENCHY.GCODE')
  end

  it 'lists every file with gcode: false' do
    expect(filenames('{ files(gcode: false) { filename } }').size).to eq 3
  end

  it 'agrees with Library::Item#gcode?' do
    expect(Library::Item.gcode).to contain_exactly(*Library::Item.all.select(&:gcode?))
    expect([gcode, upper_case, stl].map(&:gcode?)).to eq [true, true, false]
  end
end
