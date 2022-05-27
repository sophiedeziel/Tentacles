# frozen_string_literal: true
require 'sidekiq/web'

Rails.application.routes.draw do
  mount GraphiQL::Rails::Engine, at: '/graphiql', graphql_path: '/graphql' if Rails.env.development?
  mount Sidekiq::Web => "/sidekiq"
  post '/graphql', to: 'graphql#execute'

  root 'home#index'
  get '*path', to: 'home#index'
end
