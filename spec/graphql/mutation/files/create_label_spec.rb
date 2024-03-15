# frozen_string_literal: true

require 'rails_helper'

module Mutations
  module Files
    module CreateLabelSpec
      include ActiveJob::TestHelper

      RSpec.describe CreateLabel, type: :request do
        let(:variables) do
          {
            input: {
              name: 'PETG',
              color: '#ff0000'
            }
          }
        end

        describe '.resolve' do
          it 'creates a label' do
            expect do
              post '/graphql', params: { query:, variables: }
            end.to change { Label.count }.by(1)
          end

          it 'returns the label' do
            post '/graphql', params: { query:, variables: }
            json = JSON.parse(response.body)
            data = json['data']['createLabel']

            expect(data['label']).to include(
              'id' => be_present,
              'name' => 'PETG',
              'color' => '#ff0000'
            )
          end

          context 'with invalid arguments' do
            let(:variables) do
              {
                input: {
                  name: 'PETG',
                  color: 'blue'
                }
              }
            end
            it 'does not create a label' do
              expect do
                post '/graphql', params: { query:, variables: }
              end.to change { Label.count }.by(0)
            end

            it 'returns a nil label' do
              post '/graphql', params: { query:, variables: }
              json = JSON.parse(response.body)
              data = json['data']['createLabel']

              expect(data['label']).to be_nil
            end
          end
        end

        def query
          <<~GQL
            mutation CreateLabel($input: CreateLabelInput!) {
              createLabel(input: $input) {
                label {
                  id
                  name
                  color
                }
              }
            }
          GQL
        end
      end
    end
  end
end
