# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query file { gcodeSummary }', type: :request do
  let(:fields) do
    <<~GQL
      gcodeSummary {
        status analysedAt error slicer slicerVersion printSeconds filamentGrams filamentMetres toolCount toolChanges
        footprint { width depth height minX maxX minY maxY source }
        tools { tool material materialRaw colourHex grams metres }
        filamentChanges { line z layer }
      }
    GQL
  end
  let(:json) { response.parsed_body }

  def summary_of(item)
    post '/graphql', params: { query: "query($id: ID!) { file(id: $id) { #{fields} } }", variables: { id: item.id } }
    expect(json['errors']).to be_nil
    json.dig('data', 'file', 'gcodeSummary')
  end

  def sql_queries(&)
    queries = []
    counter = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    queries
  end

  describe 'the fields' do
    it 'types the summary as nullable, its lists as non-null lists, and its values as nullable' do
      expect(TentaclesSchema.get_type('File').get_field('gcodeSummary').type.to_type_signature).to eq 'GcodeSummary'
      signatures = TentaclesSchema.get_type('GcodeSummary').fields.transform_values { |f| f.type.to_type_signature }

      expect(signatures).to include('status' => 'GcodeSummaryStatus!', 'printSeconds' => 'Int',
                                    'filamentGrams' => 'Float', 'tools' => '[GcodeTool!]!',
                                    'filamentChanges' => '[GcodeFilamentChange!]!', 'footprint' => 'GcodeFootprint')
    end

    it 'leaves File.gcodeAnalysis as it is' do
      expect(TentaclesSchema.get_type('File').get_field('gcodeAnalysis').type.to_type_signature).to eq 'GcodeAnalysis'
    end
  end

  it 'is PENDING for a G-code file with no row yet' do
    expect(summary_of(create(:file_record))).to include('status' => 'PENDING', 'slicer' => nil, 'tools' => [],
                                                        'filamentChanges' => [], 'footprint' => nil)
  end

  it 'is null for a file that is not G-code' do
    item = create(:file_record)
    item.file.attach(io: StringIO.new('solid cube'), filename: 'cube.stl')

    expect(summary_of(item)).to be_nil
  end

  it 'returns the values read, with the footprint derived from the box' do
    summary = create(:gcode_summary, :ready, min_x: 2, max_x: 125.09, min_y: 10, max_y: 140, max_z: 15.2,
                                             filament_changes: [{ 'line' => 102, 'z' => 0.41, 'layer' => 2 },
                                                                { 'line' => 124, 'z' => nil, 'layer' => nil }])
    create(:gcode_summary_tool, gcode_summary: summary, tool: 0, grams: 2.5, millimetres: 800)
    create(:gcode_summary_tool, gcode_summary: summary, tool: 1, material: nil, material_raw: 'PCTG', colour_hex: nil,
                                grams: 1.25, millimetres: 450.5)

    expect(summary_of(summary.item)).to include(
      'status' => 'READY', 'slicer' => 'PrusaSlicer', 'slicerVersion' => '2.9.6', 'printSeconds' => 1828,
      'filamentGrams' => 3.75, 'filamentMetres' => 1.2505, 'toolCount' => 1, 'toolChanges' => 0,
      'footprint' => { 'width' => 123.09, 'depth' => 130.0, 'height' => 15.2, 'minX' => 2.0, 'maxX' => 125.09,
                       'minY' => 10.0, 'maxY' => 140.0, 'source' => 'moves' },
      'tools' => [
        { 'tool' => 0, 'material' => 'PLA', 'materialRaw' => 'PLA', 'colourHex' => '#DDDDDD', 'grams' => 2.5,
          'metres' => 0.8 },
        { 'tool' => 1, 'material' => nil, 'materialRaw' => 'PCTG', 'colourHex' => nil, 'grams' => 1.25,
          'metres' => 0.4505 }
      ],
      'filamentChanges' => [{ 'line' => 102, 'z' => 0.41, 'layer' => 2 }, { 'line' => 124, 'z' => nil, 'layer' => nil }]
    )
  end

  it 'has null totals when any tool is Not known, and no footprint without a box' do
    summary = create(:gcode_summary, :ready, min_x: nil)
    create(:gcode_summary_tool, gcode_summary: summary, tool: 0, grams: 2.5, millimetres: 800)
    create(:gcode_summary_tool, gcode_summary: summary, tool: 1, grams: nil, millimetres: nil)

    expect(summary_of(summary.item)).to include('filamentGrams' => nil, 'filamentMetres' => nil, 'footprint' => nil)
  end

  it 'returns the error of a FAILED summary' do
    summary = create(:gcode_summary, status: 'failed', error: 'Not a G-code text file')

    expect(summary_of(summary.item)).to include('status' => 'FAILED', 'error' => 'Not a G-code text file')
  end

  describe 'in a list of files' do
    let(:query) { "query { files { id #{fields} } }" }

    def query_count(file_count)
      Library::Item.destroy_all
      Array.new(file_count) { create(:gcode_summary_tool, gcode_summary: create(:gcode_summary, :ready)) }
      sql_queries { post '/graphql', params: { query: } }.size
    end

    it 'issues the same number of SQL queries for 1 and 5 files' do
      expect(query_count(5)).to eq(query_count(1))
      expect(json['errors']).to be_nil
    end

    it 'reads the summaries and their tools with one query each' do
      3.times { create(:gcode_summary_tool, gcode_summary: create(:gcode_summary, :ready)) }

      queries = sql_queries { post '/graphql', params: { query: } }

      expect(queries.grep(/FROM `gcode_summaries`/).size).to eq 1
      expect(queries.grep(/FROM `gcode_summary_tools`/).size).to eq 1
      expect(json['data']['files'].map { |file| file['gcodeSummary']['tools'].size }).to eq [1, 1, 1]
    end
  end
end
