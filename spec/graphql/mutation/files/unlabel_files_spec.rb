# frozen_string_literal: true

require 'rails_helper'

module Mutations
  module Files
    module UnlabelFilesSpec
      include ActiveJob::TestHelper

      RSpec.describe UnlabelFiles, type: :request do
        let(:file) { create(:file_record) }
        let(:label) { create(:label) }
        let(:variables) do
          {
            input: {
              fileIds: [file.id],
              labelIds: [label.id]
            }
          }
        end

        describe '.resolve' do
          before do
            file.labels << label
          end

          it 'detaches the label to the file' do
            expect do
              post '/graphql', params: { query:, variables: }
            end.to change { file.labels.count }.by(-1)
          end

          it 'returns the label and the file' do
            post '/graphql', params: { query:, variables: }
            json = JSON.parse(response.body)
            data = json['data']['unlabelFiles']

            expect(data['labels'][0]).to include(
              'id' => label.id.to_s
            )
            expect(data['files'][0]).to include(
              'id' => file.id.to_s
            )
          end

          context 'when the label is not attached to the file' do
            before do
              file.file_labels.destroy_all
              file.labels << create(:label, name: 'other label')
            end

            it 'does not change other labels' do
              expect do
                post '/graphql', params: { query:, variables: }
              end.to change { FileLabel.count }.by(0)
            end

            it 'returns the label and the file' do
              post '/graphql', params: { query:, variables: }
              json = JSON.parse(response.body)
              data = json['data']['unlabelFiles']

              expect(data['labels'][0]).to include(
                'id' => label.id.to_s
              )
              expect(data['files'][0]).to include(
                'id' => file.id.to_s
              )
            end
          end

          context 'with invalid arguments' do
            let(:variables) do
              {
                input: {
                  fileIds: [file.id],
                  labelIds: ['']
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
              data = json['data']['unlabelFiles']

              expect(data['labels']).to be_empty
            end

            it 'returns a nil file' do
              post '/graphql', params: { query:, variables: }
              json = JSON.parse(response.body)
              data = json['data']['unlabelFiles']

              expect(data['files']).to be_empty
            end
          end

          context 'when the file does not exist' do
            before do
              file.destroy
            end

            it 'does not create a label' do
              expect do
                post '/graphql', params: { query:, variables: }
              end.to change { Label.count }.by(0)
            end

            it 'returns a nil label' do
              post '/graphql', params: { query:, variables: }
              json = JSON.parse(response.body)
              data = json['data']['unlabelFiles']

              expect(data['labels']).to be_empty
            end

            it 'returns a nil file' do
              post '/graphql', params: { query:, variables: }
              json = JSON.parse(response.body)
              data = json['data']['unlabelFiles']

              expect(data['files']).to be_empty
            end
          end

          context 'when there is an error' do
            before do
              allow_any_instance_of(FileLabel).to receive(:destroy!).and_raise(ActiveRecord::RecordInvalid)
            end

            it 'returns a nil label' do
              post '/graphql', params: { query:, variables: }
              json = JSON.parse(response.body)
              data = json['data']['unlabelFiles']

              expect(data['labels']).to be_empty
            end

            it 'returns a nil file' do
              post '/graphql', params: { query:, variables: }
              json = JSON.parse(response.body)
              data = json['data']['unlabelFiles']

              expect(data['files']).to be_empty
            end
          end
        end

        def query
          <<~GQL
            mutation UnlabelFiles($input: UnlabelFilesInput!) {
              unlabelFiles(input: $input) {
                files {
                  id
                }
                labels {
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
