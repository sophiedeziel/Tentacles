# frozen_string_literal: true

require 'rails_helper'

module Mutations
  module AddPrinterSpec
    RSpec.describe AddPrinter, type: :request do
      let(:variables) do
        {
          input: {
            name: 'Ender 3',
            octoprintUri: 'http://192.168.0.15',
            octoprintKey: '12345678'
          }
        }
      end

      describe '.resolve' do
        it 'adds a printer' do
          expect do
            post '/graphql', params: { query:, variables: }
          end.to change { Printer.count }.by(1)
        end

        it 'returns a printer' do
          post '/graphql', params: { query:, variables: }
          json = JSON.parse(response.body)
          data = json['data']['addPrinter']

          printer = Printer.last

          expect(data['printer']).to include(
            'id' => printer.id.to_s,
            'name' => printer.name,
            'octoprintUri' => printer.octoprint_uri,
            'octoprintKey' => printer.octoprint_key
          )
        end

        context 'with invalid arguments' do
          let(:variables) do
            {
              input: {
                name: '',
                octoprintUri: 'http://192.168.0.15',
                octoprintKey: '12345678'
              }
            }
          end
          it 'does not add a printer' do
            expect do
              post '/graphql', params: { query:, variables: }
            end.to_not(change { Printer.count })
          end

          it 'returns a nil printer' do
            post '/graphql', params: { query:, variables: }
            json = JSON.parse(response.body)
            data = json['data']['addPrinter']

            expect(data['printer']).to be_nil
          end
        end
      end

      def query
        <<~GQL
          mutation addPrinter($input: AddPrinterInput!) {
            addPrinter(input: $input) {
              printer {
                id
                jobsCount
                name
                octoprintKey
                octoprintUri
              }
            }
          }
        GQL
      end
    end
  end
end
