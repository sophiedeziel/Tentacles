# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query printers { loadedFilaments filamentSlots }', type: :request do
  let(:query) { 'query { printers { id filamentSlots loadedFilaments { slot material colour updatedAt } } }' }
  let(:json) { response.parsed_body }
  let(:printers) { json['data']['printers'].index_by { |printer| printer['id'].to_i } }

  def sql_queries(&)
    queries = []
    counter = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    queries
  end

  describe 'the fields' do
    let(:printer_type) { TentaclesSchema.get_type('Printer') }
    let(:filament_type) { TentaclesSchema.get_type('LoadedFilament') }

    it 'types loadedFilaments as a non-null list of LoadedFilament and filamentSlots as Int!' do
      expect(printer_type.get_field('loadedFilaments').type.to_type_signature).to eq('[LoadedFilament!]!')
      expect(printer_type.get_field('filamentSlots').type.to_type_signature).to eq('Int!')
    end

    it 'exposes the slot, material, colour and updatedAt of a loaded filament, and the waiting jobs asking for it' do
      signatures = filament_type.fields.transform_values { |field| field.type.to_type_signature }

      expect(signatures).to eq('slot' => 'Int!', 'material' => 'String!', 'colour' => 'String!',
                               'updatedAt' => 'ISO8601DateTime!', 'waitingJobsAskingCount' => 'Int!')
    end

    it 'exposes takesJobs, a non-null Boolean' do
      expect(printer_type.get_field('takesJobs').type.to_type_signature).to eq('Boolean!')
    end
  end

  it 'returns an empty list for a printer with no filament set, and its filament slots' do
    printer = create(:printer)

    post '/graphql', params: { query: }

    expect(json['errors']).to be_nil
    expect(printers[printer.id]).to eq('id' => printer.id.to_s, 'filamentSlots' => 1, 'loadedFilaments' => [])
  end

  it "returns each printer's loaded filaments, by slot, as typed" do
    printer = create(:printer, filament_slots: 3)
    other = create(:printer, name: 'Other')
    changed_at = Time.zone.parse('2026-11-20 14:30:00')
    create(:printer_loaded_filament, printer:, slot: 3, material: 'petg', colour: 'Grey')
    create(:printer_loaded_filament, printer:, slot: 1, material: 'PLA', colour: ' Galaxy  Black ',
                                     updated_at: changed_at)
    create(:printer_loaded_filament, printer: other, material: 'ABS', colour: 'Red')

    post '/graphql', params: { query: }

    expect(json['errors']).to be_nil
    expect(printers[printer.id]['filamentSlots']).to eq 3
    expect(printers[printer.id]['loadedFilaments']).to match(
      [{ 'slot' => 1, 'material' => 'PLA', 'colour' => 'Galaxy Black', 'updatedAt' => '2026-11-20T14:30:00Z' },
       { 'slot' => 3, 'material' => 'PETG', 'colour' => 'Grey', 'updatedAt' => be_present }]
    )
    expect(printers[other.id]['loadedFilaments']).to match(
      [a_hash_including('slot' => 1, 'material' => 'ABS', 'colour' => 'Red')]
    )
  end

  describe 'batching' do
    def query_count(printer_count)
      Printer.delete_all
      Array.new(printer_count) { create(:printer_loaded_filament, printer: create(:printer)) }
      sql_queries { post '/graphql', params: { query: } }.size
    end

    it 'issues the same number of SQL queries for 1 and 5 printers' do
      expect(query_count(5)).to eq(query_count(1))
      expect(json['data']['printers'].size).to eq 1
    end

    it 'reads the loaded filaments of every printer with one query' do
      3.times { create(:printer_loaded_filament, printer: create(:printer)) }

      queries = sql_queries { post '/graphql', params: { query: } }

      expect(queries.grep(/printer_loaded_filaments/).size).to eq 1
      expect(json['data']['printers'].map { |printer| printer['loadedFilaments'].size }).to eq [1, 1, 1]
    end
  end
end
