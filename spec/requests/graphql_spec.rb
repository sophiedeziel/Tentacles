# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GraphqlController, type: :request do
  describe 'POST /graphql' do
    it 'returns a successful response' do
      post '/graphql', params: { query: '' }
      expect(response).to have_http_status(200)
    end

    it 'handles an empty query' do
      post '/graphql', params: { query: '' }
      json = JSON.parse(response.body)

      expect(json['errors'].size).to eq 1
      expect(json.dig('errors', 0, 'message')).to eq 'Unexpected end of document'
    end
  end
end
