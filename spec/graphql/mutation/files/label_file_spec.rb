# frozen_string_literal: true

require 'rails_helper'

module Mutations
  module Files
    module LabelFileSpec
      include ActiveJob::TestHelper

      RSpec.describe LabelFile, type: :request do
        let(:file) { create(:file_record) }
        let(:label) { create(:label) }
        let(:variables) do
          {
            input: {
              fileId: file.id,
              labelId: label.id
            }
          }
        end

        describe '.resolve' do
          it 'attaches the label to the file' do
            expect do
              post '/graphql', params: { query:, variables: }
            end.to change { file.labels.count }.by(1)
          end

          it 'returns the label and the file' do
            post '/graphql', params: { query:, variables: }
            json = JSON.parse(response.body)
            data = json['data']['labelFile']

            expect(data['label']).to include(
              'id' => label.id.to_s
            )
            expect(data['file']).to include(
              'id' => file.id.to_s
            )
          end

          context 'with invalid arguments' do
            let(:variables) do
              {
                input: {
                  fileId: file.id,
                  labelId: ''
                }
              }
            end
            it 'does not create a label' do
              expect do
                post '/graphql', params: { query:, variables: }
              end.to change { file.labels.count }.by(0)
            end

            it 'returns a nil label' do
              post '/graphql', params: { query:, variables: }
              json = JSON.parse(response.body)
              data = json['data']['labelFile']

              expect(data['label']).to be_nil
            end

            it 'returns a nil file' do
              post '/graphql', params: { query:, variables: }
              json = JSON.parse(response.body)
              data = json['data']['labelFile']

              expect(data['file']).to be_nil
            end
          end
        end

        def query
          <<~GQL
            mutation LabelFile($input: LabelFileInput!) {
              labelFile(input: $input) {
                file {
                  id
                }
                label {
                  id
                }
              }
            }
          GQL
        end
      end
    end
  end
end
