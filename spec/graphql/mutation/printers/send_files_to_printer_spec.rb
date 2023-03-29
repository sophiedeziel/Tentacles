# frozen_string_literal: true

require 'rails_helper'

module Mutations
  module Printers
    module SendFilesToPrintersSpec
      include ActiveJob::TestHelper

      RSpec.describe SendFilesToPrinters, type: :request do
        let!(:files) { create_list(:file_manager_file, 2) }
        let!(:printers) { create_list(:printer, 2) }
        let(:variables) do
          {
            input: {
              fileIds: files.map(&:id),
              printerIds: printers.map(&:id)
            }
          }
        end

        describe '.resolve' do
          it 'enqueues the job' do
            expect do
              post '/graphql', params: { query:, variables: }
            end.to change { enqueued_jobs.count }.by(1)
          end

          it 'returns true' do
            post '/graphql', params: { query:, variables: }
            json = JSON.parse(response.body)
            data = json['data']['sendFilesToPrinters']

            expect(data['jobEnqueued']).to be_truthy
          end

          context 'with invalid arguments' do
            let(:variables) do
              {
                input: {
                  fileIds: [],
                  printerIds: []
                }
              }
            end
            it 'does not add a printer' do
              expect do
                post '/graphql', params: { query:, variables: }
              end.to change { enqueued_jobs.count }.by(0)
            end

            it 'returns a nil printer' do
              post '/graphql', params: { query:, variables: }
              json = JSON.parse(response.body)
              data = json['data']['sendFilesToPrinters']

              expect(data['jobEnqueued']).to be_falsey
            end
          end
        end

        def query
          <<~GQL
            mutation SendFilesToPrinters($input: SendFilesToPrintersInput!) {
              sendFilesToPrinters(input: $input) {
                jobEnqueued
              }
            }
          GQL
        end
      end
    end
  end
end
