# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GraphqlController, type: :request do
  describe 'POST /graphql' do
    it 'handles an empty query' do
      post '/graphql', params: { query: '' }
      json = response.parsed_body

      expect(json['errors'].size).to eq 1
      expect(json.dig('errors', 0, 'message')).to eq 'Unexpected end of document'
    end
  end
end
